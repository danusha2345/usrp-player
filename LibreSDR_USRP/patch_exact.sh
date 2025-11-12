#!/bin/bash
# Точный путь к файлу FPGA
TARGET="/usr/local/share/uhd/images/usrp_b210_fpga.bin"

echo "Применяю патч LibreSDR..."
echo "Целевой файл: $TARGET"

# Проверка существования файла
if [ -f "$TARGET" ]; then
    # Создаём резервную копию если её ещё нет
    if [ ! -f "$TARGET.backup" ]; then
        sudo cp "$TARGET" "$TARGET.backup"
        echo "Создана резервная копия: $TARGET.backup"
    fi
    
    # Применяем патч
    sudo cp libresdr_b210.bin "$TARGET"
    echo "Патч успешно применён!"
    
    # Проверяем размер
    SIZE=$(ls -la "$TARGET" | awk '{print $5}')
    echo "Размер нового файла: $SIZE байт"
else
    echo "ОШИБКА: Файл $TARGET не найден!"
fi
