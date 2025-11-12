#!/bin/bash
# Скрипт для вывода ВСЕХ параметров LibreSDR B210
# Использование: ./show_b210_specs.sh [serial]

SERIAL="${1:-DW49CI6}"
ARGS="serial=$SERIAL"

echo "=================================================="
echo "  LibreSDR B210 - ВСЕ параметры устройства"
echo "=================================================="
echo ""
echo "Считываем полную информацию с устройства..."
echo "(это займёт ~3 секунды)"
echo ""

# Получаем полный вывод один раз
PROBE_OUTPUT=$(uhd_usrp_probe --args="$ARGS" 2>&1)

echo "=================================================="
echo "📋 БАЗОВАЯ ИНФОРМАЦИЯ"
echo "=================================================="
echo "$PROBE_OUTPUT" | grep -E "Device:|Mboard:|serial:|name:|product:|revision:|FW Version:|FPGA Version:"
echo ""

echo "=================================================="
echo "⏱️  СИНХРОНИЗАЦИЯ"
echo "=================================================="
echo "$PROBE_OUTPUT" | grep -E "Time sources:|Clock sources:|Sensors: ref_locked"
echo ""

echo "=================================================="
echo "📡 TX FRONTEND A (Передатчик, канал 1)"
echo "=================================================="
echo "$PROBE_OUTPUT" | sed -n '/TX Frontend: A/,/TX Frontend: B/p' | head -30
echo ""

echo "=================================================="
echo "📡 TX FRONTEND B (Передатчик, канал 2)"
echo "=================================================="
echo "$PROBE_OUTPUT" | sed -n '/TX Frontend: B/,/TX Codec/p' | head -30
echo ""

echo "=================================================="
echo "📻 RX FRONTEND A (Приёмник, канал 1)"
echo "=================================================="
echo "$PROBE_OUTPUT" | sed -n '/RX Frontend: A/,/RX Frontend: B/p' | head -40
echo ""

echo "=================================================="
echo "📻 RX FRONTEND B (Приёмник, канал 2)"
echo "=================================================="
echo "$PROBE_OUTPUT" | sed -n '/RX Frontend: B/,/RX Codec/p' | head -40
echo ""

echo "=================================================="
echo "⚙️  RX DSP (Цифровая обработка сигналов)"
echo "=================================================="
echo "$PROBE_OUTPUT" | sed -n '/RX DSP: 0/,/RX DSP: 1/p' | head -20
echo "$PROBE_OUTPUT" | sed -n '/RX DSP: 1/,/TX DSP/p' | head -20
echo ""

echo "=================================================="
echo "⚙️  TX DSP (Цифровая обработка сигналов)"
echo "=================================================="
echo "$PROBE_OUTPUT" | sed -n '/TX DSP: 0/,/TX DSP: 1/p' | head -20
echo "$PROBE_OUTPUT" | sed -n '/TX DSP: 1/,/TX Dboard/p' | head -20
echo ""

echo "=================================================="
echo "🔌 CODECS"
echo "=================================================="
echo "$PROBE_OUTPUT" | grep -A2 "RX Codec:"
echo "$PROBE_OUTPUT" | grep -A2 "TX Codec:"
echo ""

echo "=================================================="
echo "🌡️  СЕНСОРЫ (подробно)"
echo "=================================================="
echo "$PROBE_OUTPUT" | grep "Sensors:" | head -10
echo ""

echo "=================================================="
echo "📊 СВОДНАЯ ТАБЛИЦА ДИАПАЗОНОВ"
echo "=================================================="
echo ""
echo "TX (Передатчик):"
echo "$PROBE_OUTPUT" | grep -A5 "TX Frontend: A" | grep -E "(Freq range|Gain range|Bandwidth range|Antennas)" | head -4
echo ""
echo "RX (Приёмник):"
echo "$PROBE_OUTPUT" | grep -A5 "RX Frontend: A" | grep -E "(Freq range|Gain range|Bandwidth range|Antennas)" | head -4
echo ""

echo "=================================================="
echo "  ИТОГО:"
echo "  - 2x2 MIMO (2 TX + 2 RX каналов)"
echo "  - Диапазон: 50 MHz - 6 GHz"
echo "  - TX Gain: 0-89.8 dB"
echo "  - RX Gain: 0-76 dB"
echo "  - Полоса: 200 kHz - 56 MHz"
echo "  - LibreSDR патч: Активен"
echo "=================================================="
echo ""
echo "Для полного вывода: uhd_usrp_probe --args=\"serial=$SERIAL\""
