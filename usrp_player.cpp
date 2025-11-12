/*
 * USRP B210 Signal Player for SignalSim
 * 
 * Передача IF данных через USRP B210 с использованием UHD
 * Поддерживает 8-bit и 16-bit IQ форматы
 * 
 * Компиляция:
 * g++ -o usrp_player usrp_player.cpp -luhd -lboost_program_options -lboost_system -lboost_thread -pthread
 */

#include <uhd/device.hpp>
#include <uhd/stream.hpp>
#include <uhd/types/device_addr.hpp>
#include <uhd/types/tune_request.hpp>
#include <uhd/usrp/multi_usrp.hpp>
#include <uhd/utils/safe_main.hpp>
#include <uhd/utils/thread.hpp>
#include <boost/format.hpp>
#include <boost/program_options.hpp>
#include <boost/thread/thread.hpp>
#include <boost/algorithm/string.hpp>
#include <chrono>
#include <complex>
#include <csignal>
#include <fstream>
#include <iostream>
#include <thread>
#include <queue>
#include <mutex>
#include <condition_variable>

namespace po = boost::program_options;

// Глобальная переменная для остановки
static bool stop_signal_called = false;
void sig_int_handler(int) { stop_signal_called = true; }

// Вспомогательная функция для форматирования размера файла
std::string format_file_size(size_t size) {
    const char* units[] = {"B", "KB", "MB", "GB", "TB"};
    int unit_index = 0;
    double size_d = static_cast<double>(size);
    
    while (size_d >= 1024.0 && unit_index < 4) {
        size_d /= 1024.0;
        unit_index++;
    }
    
    return str(boost::format("%.2f %s") % size_d % units[unit_index]);
}

// Структура для буферов
template <typename samp_type>
struct BufferQueue {
    std::queue<std::vector<samp_type>> buffers;
    std::mutex mutex;
    std::condition_variable cv;
    bool finished = false;
    size_t max_buffers = 32; // Максимум буферов в очереди
};

// Функция чтения и конвертации в отдельном потоке
template <typename samp_type>
void reader_thread(
    BufferQueue<samp_type>* queue,
    const std::string& file,
    size_t samps_per_buff,
    bool is_8bit,
    int bit_shift)
{
    std::ifstream infile(file.c_str(), std::ifstream::binary);
    if (!infile.is_open()) {
        std::cerr << "Ошибка открытия файла в потоке чтения" << std::endl;
        return;
    }

    std::vector<int8_t> buff_8bit;
    std::vector<int16_t> buff_16bit;

    if (is_8bit) {
        buff_8bit.resize(samps_per_buff * 2);
    } else {
        buff_16bit.resize(samps_per_buff * 2);
    }

    while (not stop_signal_called) {
        // Создаём буфер для конвертированных данных
        std::vector<samp_type> buff(samps_per_buff);
        size_t samples_read = 0;

        if (is_8bit) {
            infile.read(reinterpret_cast<char*>(buff_8bit.data()),
                       buff_8bit.size() * sizeof(int8_t));
            size_t bytes_read = infile.gcount();
            samples_read = bytes_read / 2;

            // Конвертируем 8-bit в комплексные float
            for (size_t i = 0; i < samples_read; i++) {
                float i_val = static_cast<float>(buff_8bit[i * 2]) / 128.0f;
                float q_val = static_cast<float>(buff_8bit[i * 2 + 1]) / 128.0f;

                if (bit_shift > 0) {
                    float scale = 1.0f / (1 << bit_shift);
                    i_val *= scale;
                    q_val *= scale;
                }

                buff[i] = samp_type(i_val, q_val);
            }
        } else {
            infile.read(reinterpret_cast<char*>(buff_16bit.data()),
                       buff_16bit.size() * sizeof(int16_t));
            size_t values_read = infile.gcount() / sizeof(int16_t);
            samples_read = values_read / 2;

            for (size_t i = 0; i < samples_read; i++) {
                float i_val = static_cast<float>(buff_16bit[i * 2]) / 32768.0f;
                float q_val = static_cast<float>(buff_16bit[i * 2 + 1]) / 32768.0f;

                if (bit_shift > 0) {
                    float scale = 1.0f / (1 << bit_shift);
                    i_val *= scale;
                    q_val *= scale;
                }

                buff[i] = samp_type(i_val, q_val);
            }
        }

        // Если конец файла - начинаем сначала
        if (samples_read == 0 || infile.eof()) {
            infile.clear();
            infile.seekg(0, std::ios::beg);
            continue;
        }

        // Изменяем размер буфера под реальное количество сэмплов
        buff.resize(samples_read);

        // Добавляем буфер в очередь
        {
            std::unique_lock<std::mutex> lock(queue->mutex);
            // Ждём если очередь заполнена
            queue->cv.wait(lock, [queue] {
                return queue->buffers.size() < queue->max_buffers || stop_signal_called;
            });

            if (stop_signal_called) break;

            queue->buffers.push(std::move(buff));
        }
        queue->cv.notify_one();
    }

    // Помечаем что чтение завершено
    {
        std::lock_guard<std::mutex> lock(queue->mutex);
        queue->finished = true;
    }
    queue->cv.notify_one();

    infile.close();
}

// Функция передачи данных с многопоточной буферизацией
template <typename samp_type>
void send_from_file(
    uhd::tx_streamer::sptr tx_stream,
    const std::string& file,
    size_t samps_per_buff,
    bool is_8bit,
    int bit_shift)
{
    uhd::tx_metadata_t md;
    md.start_of_burst = true;
    md.end_of_burst = false;
    md.has_time_spec = false;

    // Проверяем файл
    std::ifstream test_file(file.c_str(), std::ifstream::binary);
    if (!test_file.is_open()) {
        throw std::runtime_error("Не удалось открыть файл: " + file);
    }
    test_file.seekg(0, std::ios::end);
    size_t file_size = test_file.tellg();
    test_file.close();

    std::cout << "* Размер файла: " << format_file_size(file_size) << std::endl;

    // Создаём очередь буферов
    BufferQueue<samp_type> queue;

    // Запускаем поток чтения
    std::cout << "* Запуск многопоточной буферизации..." << std::endl;
    std::thread reader(reader_thread<samp_type>, &queue, file, samps_per_buff, is_8bit, bit_shift);

    // Ждём заполнения начальных буферов
    std::this_thread::sleep_for(std::chrono::milliseconds(500));

    // Счетчики
    size_t total_samples = 0;
    size_t num_tx_samps = 0;
    auto start_time = std::chrono::steady_clock::now();

    std::cout << "* Начинаем передачу..." << std::endl;

    while (not stop_signal_called) {
        std::vector<samp_type> buff;

        // Получаем буфер из очереди
        {
            std::unique_lock<std::mutex> lock(queue.mutex);
            queue.cv.wait(lock, [&queue] {
                return !queue.buffers.empty() || queue.finished || stop_signal_called;
            });

            if (stop_signal_called) break;

            if (queue.buffers.empty()) {
                if (queue.finished) break;
                continue;
            }

            buff = std::move(queue.buffers.front());
            queue.buffers.pop();
        }
        queue.cv.notify_one();

        // Отправляем данные
        num_tx_samps = tx_stream->send(&buff.front(), buff.size(), md);
        if (num_tx_samps < buff.size()) {
            std::cerr << "Отправлено меньше сэмплов чем запрошено" << std::endl;
        }

        md.start_of_burst = false;
        total_samples += num_tx_samps;

        // Статистика каждые 5 секунд
        auto now = std::chrono::steady_clock::now();
        auto time_passed = std::chrono::duration_cast<std::chrono::seconds>(now - start_time).count();
        if (time_passed >= 5) {
            double rate = total_samples / static_cast<double>(time_passed) / 1e6;
            size_t queue_size;
            {
                std::lock_guard<std::mutex> lock(queue.mutex);
                queue_size = queue.buffers.size();
            }
            std::cout << boost::format("Статистика: %.2f MS/s (буферов в очереди: %d)")
                % rate % queue_size << std::endl;
            start_time = now;
            total_samples = 0;
        }
    }

    // Останавливаем поток чтения
    stop_signal_called = true;
    queue.cv.notify_all();
    reader.join();

    // Отправляем конец потока
    md.end_of_burst = true;
    tx_stream->send("", 0, md);
}

int UHD_SAFE_MAIN(int argc, char* argv[])
{
    // Переменные для параметров
    std::string file, args, ant, subdev, ref, wirefmt, channel_list;
    double rate, freq, gain, bw, lo_offset;
    size_t spb;
    bool is_8bit = false;
    int bit_shift = 0;
    
    // Настройка программных опций
    po::options_description desc("Параметры USRP B210 плеера для SignalSim");
    desc.add_options()
        ("help", "показать эту справку")
        ("file", po::value<std::string>(&file)->default_value(""), 
            "путь к файлу с IF данными (обязательный)")
        ("args", po::value<std::string>(&args)->default_value(""), 
            "аргументы USRP устройства")
        ("spb", po::value<size_t>(&spb)->default_value(10000), 
            "сэмплов на буфер")
        ("rate", po::value<double>(&rate), 
            "частота дискретизации в Hz (ОБЯЗАТЕЛЬНЫЙ для 8-bit файлов)")
        ("freq", po::value<double>(&freq), 
            "центральная частота в Hz (ОБЯЗАТЕЛЬНЫЙ для 8-bit файлов)")
        ("gain", po::value<double>(&gain)->default_value(20), 
            "усиление TX в dB (0-89.75)")
        ("ant", po::value<std::string>(&ant)->default_value("TX/RX"), 
            "антенна TX")
        ("subdev", po::value<std::string>(&subdev)->default_value("A:A"), 
            "subdevice specification")
        ("bw", po::value<double>(&bw)->default_value(0), 
            "аналоговая полоса пропускания в Hz (0 = авто)")
        ("ref", po::value<std::string>(&ref)->default_value("internal"), 
            "источник опорной частоты (internal, external, gpsdo)")
        ("lo-offset", po::value<double>(&lo_offset)->default_value(0), 
            "смещение LO от центральной частоты в Hz")
        ("wirefmt", po::value<std::string>(&wirefmt)->default_value("sc16"), 
            "формат wire (sc16 или sc8)")
        ("channels", po::value<std::string>(&channel_list)->default_value("0"), 
            "каналы для использования (по умолчанию \"0\")")
        ("8bit", "входной файл в формате 8-bit IQ")
        ("shift", po::value<int>(&bit_shift)->default_value(0), 
            "битовый сдвиг вправо (0-4) для уменьшения амплитуды")
    ;
    
    po::variables_map vm;
    po::store(po::parse_command_line(argc, argv, desc), vm);
    po::notify(vm);
    
    // Обработка помощи и проверка обязательных параметров
    bool show_help = vm.count("help") || file.empty();
    
    // Для 8-bit файлов rate и freq обязательны
    if (!show_help && vm.count("8bit")) {
        if (!vm.count("rate") || !vm.count("freq")) {
            std::cerr << "ОШИБКА: Для 8-bit файлов параметры --rate и --freq обязательны!" << std::endl;
            show_help = true;
        }
    }
    
    if (show_help) {
        std::cout << boost::format("USRP B210 плеер для SignalSim %s") % desc << std::endl;
        std::cout << std::endl
                  << "Примеры использования:" << std::endl
                  << "  Передача Multi L1 Band (15 MHz):" << std::endl
                  << "    usrp_player --file Multi_L1_Band_15MHz.C8 --8bit --freq 1568.259e6 --rate 15e6 --gain 30" << std::endl
                  << std::endl
                  << "  Передача ГЛОНАСС L1+L2 (46.5 MHz):" << std::endl
                  << "    usrp_player --file GPS_BDS_GAL_GLO_L1G1_46MHz.C8 --8bit --freq 1582.21e6 --rate 46.5e6 --gain 45" << std::endl
                  << std::endl
                  << "  Передача GPS+BDS+GAL L1 (5 MHz):" << std::endl
                  << "    usrp_player --file GPS_BDS_GAL_L1_5MHz.C8 --8bit --freq 1575.42e6 --rate 5e6 --gain 35" << std::endl
                  << std::endl;
        return ~0;
    }
    
    is_8bit = vm.count("8bit") > 0;
    
    // Установка обработчика сигнала
    std::signal(SIGINT, &sig_int_handler);
    
    std::cout << "======================================" << std::endl;
    std::cout << "USRP B210 плеер для SignalSim" << std::endl;
    std::cout << "======================================" << std::endl;
    std::cout << "* Файл: " << file << std::endl;
    std::cout << "* Формат: " << (is_8bit ? "8-bit IQ" : "16-bit IQ") << std::endl;
    std::cout << "* Частота: " << (freq/1e6) << " MHz" << std::endl;
    std::cout << "* Частота дискретизации: " << (rate/1e6) << " MS/s" << std::endl;
    std::cout << "* Усиление: " << gain << " dB" << std::endl;
    if (bit_shift > 0) {
        std::cout << "* Битовый сдвиг: " << bit_shift << " бит вправо" << std::endl;
    }
    
    // Создание USRP устройства с оптимизацией для высоких скоростей
    std::string device_args = args;
    
    // Добавляем критические параметры для 46.5+ MS/s если не указаны
    if (rate >= 46e6) {
        // Официальная рекомендация из документации UHD для B210
        if (device_args.find("recv_frame_size") == std::string::npos) {
            if (!device_args.empty()) device_args += ",";
            device_args += "recv_frame_size=1024";
        }
        // Дополнительная оптимизация количества фреймов
        if (device_args.find("num_recv_frames") == std::string::npos) {
            if (!device_args.empty()) device_args += ",";
            device_args += "num_recv_frames=256,num_send_frames=256";
        }
        // Явно указываем master clock rate для стабильности
        if (device_args.find("master_clock_rate") == std::string::npos) {
            if (!device_args.empty()) device_args += ",";
            device_args += "master_clock_rate=46.5e6";
        }
    }
    
    std::cout << std::endl << "Создание USRP устройства с args: " << device_args << "..." << std::endl;
    uhd::usrp::multi_usrp::sptr usrp = uhd::usrp::multi_usrp::make(device_args);
    
    // Вывод информации об устройстве
    std::cout << "* Используется устройство: " << usrp->get_pp_string() << std::endl;
    
    // Установка subdevice
    if (not subdev.empty()) {
        usrp->set_tx_subdev_spec(subdev);
    }
    
    // Парсинг списка каналов
    std::vector<size_t> channel_nums;
    std::vector<std::string> channel_strings;
    boost::split(channel_strings, channel_list, boost::is_any_of("\"',"));
    for (size_t ch = 0; ch < channel_strings.size(); ch++) {
        size_t chan = std::stoi(channel_strings[ch]);
        if (chan >= usrp->get_tx_num_channels()) {
            throw std::runtime_error("Неверный номер канала");
        }
        channel_nums.push_back(chan);
    }
    
    // Установка частоты дискретизации
    std::cout << boost::format("Установка TX частоты дискретизации: %f MS/s...") % (rate / 1e6)
              << std::endl;
    usrp->set_tx_rate(rate);
    std::cout << boost::format("Фактическая TX частота: %f MS/s")
                     % (usrp->get_tx_rate() / 1e6)
              << std::endl;
    
    // Установка опорной частоты
    if (ref == "external" || ref == "gpsdo") {
        usrp->set_clock_source(ref);
        usrp->set_time_source(ref);
        std::cout << "* Используется " << ref << " опорная частота" << std::endl;
    }
    
    // Настройка каналов
    for (size_t ch = 0; ch < channel_nums.size(); ch++) {
        size_t channel = channel_nums[ch];
        
        // Установка центральной частоты
        std::cout << boost::format("Установка TX частоты канала %d: %f MHz...") 
                    % channel % (freq / 1e6) << std::endl;
        uhd::tune_request_t tune_request(freq);
        if (lo_offset != 0) {
            tune_request.rf_freq_policy = uhd::tune_request_t::POLICY_MANUAL;
            tune_request.rf_freq = freq + lo_offset;
        }
        usrp->set_tx_freq(tune_request, channel);
        std::cout << boost::format("Фактическая TX частота канала %d: %f MHz")
                        % channel % (usrp->get_tx_freq(channel) / 1e6)
                  << std::endl;
        
        // Установка усиления
        std::cout << boost::format("Установка TX усиления канала %d: %f dB...") 
                    % channel % gain << std::endl;
        usrp->set_tx_gain(gain, channel);
        std::cout << boost::format("Фактическое TX усиление канала %d: %f dB")
                        % channel % usrp->get_tx_gain(channel)
                  << std::endl;
        
        // Установка полосы пропускания
        if (bw == 0) {
            // Автоматическая настройка полосы = частота дискретизации для оптимальной фильтрации
            bw = rate;
            std::cout << boost::format("Автоматическая установка TX полосы = частоте дискретизации: %f MHz") 
                        % (bw / 1e6) << std::endl;
        }
        std::cout << boost::format("Установка TX полосы канала %d: %f MHz...") 
                    % channel % (bw / 1e6) << std::endl;
        usrp->set_tx_bandwidth(bw, channel);
        std::cout << boost::format("Фактическая TX полоса канала %d: %f MHz")
                        % channel % (usrp->get_tx_bandwidth(channel) / 1e6)
                  << std::endl;
        
        // Установка антенны
        usrp->set_tx_antenna(ant, channel);
        std::cout << boost::format("Используется TX антенна канала %d: %s") 
                    % channel % usrp->get_tx_antenna(channel) << std::endl;
    }
    
    // Настройка уровня приоритета потока
    if (not uhd::set_thread_priority_safe()) {
        std::cerr << "Не удалось установить приоритет потока" << std::endl;
    }
    
    // Создание TX streamer с увеличенными буферами для высоких скоростей
    uhd::stream_args_t stream_args("fc32", wirefmt);
    stream_args.channels = channel_nums;
    
    // Оптимизация буферов для высоких скоростей согласно документации
    if (rate >= 46e6) {
        // Критические параметры для 46.5+ MS/s
        stream_args.args["num_send_frames"] = "128";
        stream_args.args["send_buff_fullness"] = "0.9";
        // Для 8-bit данных можем использовать sc8 wire format для экономии полосы
        if (is_8bit && wirefmt == "sc16") {
            std::cout << "* Переключение на sc8 wire format для экономии USB полосы" << std::endl;
            stream_args = uhd::stream_args_t("fc32", "sc8");
            stream_args.channels = channel_nums;
            stream_args.args["peak"] = "0.8";  // Масштабирование динамического диапазона
        }
    } else if (rate > 30e6) {
        stream_args.args["num_send_frames"] = "64";
        stream_args.args["send_buff_fullness"] = "0.9";
    }
    
    uhd::tx_streamer::sptr tx_stream = usrp->get_tx_stream(stream_args);
    
    // Проверка размера буфера
    size_t max_spb = tx_stream->get_max_num_samps();
    if (spb > max_spb) {
        std::cerr << boost::format("Предупреждение: размер буфера %u превышает максимум %u, "
                                  "используется максимум") % spb % max_spb << std::endl;
        spb = max_spb;
    }
    std::cout << boost::format("* Размер буфера: %u сэмплов") % spb << std::endl;
    
    // Запуск передачи
    send_from_file<std::complex<float>>(tx_stream, file, spb, is_8bit, bit_shift);
    
    // Завершение
    std::cout << std::endl << "Передача завершена!" << std::endl;
    
    return EXIT_SUCCESS;
}