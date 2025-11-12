#!/bin/bash
# Скрипт для вывода полных параметров LibreSDR B210
# Использование: ./show_b210_specs.sh [serial]

SERIAL="${1:-DW49CI6}"
ARGS="serial=$SERIAL"

echo "=================================================="
echo "  LibreSDR B210 - Полные характеристики"
echo "=================================================="
echo ""
echo "Считываем информацию с устройства..."
echo ""

# Один раз получаем весь вывод uhd_usrp_probe
PROBE_OUTPUT=$(uhd_usrp_probe --args="$ARGS" 2>&1)

# Функция для извлечения значения из вывода
get_value() {
    echo "$PROBE_OUTPUT" | grep -A1 "$1" | tail -1 | sed 's/^[[:space:]]*//'
}

echo "📋 БАЗОВАЯ ИНФОРМАЦИЯ:"
echo "  Serial: $SERIAL"
echo "$PROBE_OUTPUT" | grep -E "(Mboard:|name:|serial:|product:|revision:|FW Version:|FPGA Version:)" | head -10
echo ""

echo "📡 TX ПАРАМЕТРЫ (Передатчик):"
echo "$PROBE_OUTPUT" | grep -A20 "TX Frontend: A" | grep -E "(Name:|Freq range:|Gain range|Bandwidth range:|Antennas:)" | head -10
echo ""

echo "📻 RX ПАРАМЕТРЫ (Приёмник):"
echo "$PROBE_OUTPUT" | grep -A20 "RX Frontend: A" | grep -E "(Name:|Freq range:|Gain range|Bandwidth range:|Antennas:)" | head -10
echo ""

echo "⚙️  СИНХРОНИЗАЦИЯ:"
echo "$PROBE_OUTPUT" | grep -E "(Time sources:|Clock sources:|Sensors:)"
echo ""

echo "=================================================="
echo "  Ключевые характеристики:"
echo "=================================================="

# Парсим основные параметры
TX_FREQ=$(echo "$PROBE_OUTPUT" | grep -A2 "TX Frontend: A" | grep "Freq range:" | head -1)
TX_GAIN=$(echo "$PROBE_OUTPUT" | grep -A4 "TX Frontend: A" | grep "Gain range" | head -1)
TX_BW=$(echo "$PROBE_OUTPUT" | grep -A6 "TX Frontend: A" | grep "Bandwidth range:" | head -1)

RX_FREQ=$(echo "$PROBE_OUTPUT" | grep -A2 "RX Frontend: A" | grep "Freq range:" | head -1)
RX_GAIN=$(echo "$PROBE_OUTPUT" | grep -A4 "RX Frontend: A" | grep "Gain range" | head -1)
RX_BW=$(echo "$PROBE_OUTPUT" | grep -A6 "RX Frontend: A" | grep "Bandwidth range:" | head -1)

echo ""
echo "TX (Передатчик):"
echo "  $TX_FREQ"
echo "  $TX_GAIN"
echo "  $TX_BW"
echo ""
echo "RX (Приёмник):"
echo "  $RX_FREQ"
echo "  $RX_GAIN"
echo "  $RX_BW"
echo ""

echo "=================================================="
echo "  Каналы: 2x2 MIMO (2 TX + 2 RX)"
echo "  USB: 3.0"
echo "  LibreSDR патч: Активен"
echo "=================================================="
echo ""
echo "Для полного вывода: uhd_usrp_probe --args=\"serial=$SERIAL\""
echo "Для дерева: uhd_usrp_probe --args=\"serial=$SERIAL\" --tree"
