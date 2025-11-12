#!/bin/bash
# Скрипт для вывода полных параметров LibreSDR B210
# Использование: ./show_b210_specs.sh [serial]

SERIAL="${1:-DW49CI6}"
ARGS="serial=$SERIAL"

echo "=================================================="
echo "  LibreSDR B210 - Полные характеристики"
echo "=================================================="
echo ""

# Базовая информация
echo "📋 БАЗОВАЯ ИНФОРМАЦИЯ:"
echo "  Serial: $SERIAL"
NAME=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/name 2>/dev/null)
echo "  Название: $NAME"
FW_VER=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/fw_version 2>/dev/null)
echo "  Firmware: $FW_VER"
FPGA_VER=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/fpga_version 2>/dev/null)
echo "  FPGA: $FPGA_VER"
USB_VER=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/usb_version 2>/dev/null)
echo "  USB: $USB_VER"
echo ""

# TX Frontend A
echo "📡 TX FRONTEND A (Передатчик, канал 1):"
TX_A_FREQ=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/tx_frontends/A/freq/range 2>/dev/null)
echo "  Диапазон частот: $TX_A_FREQ"
TX_A_GAIN=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/tx_frontends/A/gains/PGA/range 2>/dev/null)
echo "  Диапазон усиления: $TX_A_GAIN"
TX_A_BW=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/tx_frontends/A/bandwidth/range 2>/dev/null)
echo "  Диапазон полосы: $TX_A_BW"
TX_A_ANT=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/tx_frontends/A/antenna/options 2>/dev/null)
echo "  Антенны: $TX_A_ANT"
echo ""

# TX Frontend B
echo "📡 TX FRONTEND B (Передатчик, канал 2):"
TX_B_FREQ=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/tx_frontends/B/freq/range 2>/dev/null)
echo "  Диапазон частот: $TX_B_FREQ"
TX_B_GAIN=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/tx_frontends/B/gains/PGA/range 2>/dev/null)
echo "  Диапазон усиления: $TX_B_GAIN"
TX_B_BW=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/tx_frontends/B/bandwidth/range 2>/dev/null)
echo "  Диапазон полосы: $TX_B_BW"
echo ""

# RX Frontend A
echo "📻 RX FRONTEND A (Приёмник, канал 1):"
RX_A_FREQ=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/rx_frontends/A/freq/range 2>/dev/null)
echo "  Диапазон частот: $RX_A_FREQ"
RX_A_GAIN=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/rx_frontends/A/gains/PGA/range 2>/dev/null)
echo "  Диапазон усиления: $RX_A_GAIN"
RX_A_BW=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/rx_frontends/A/bandwidth/range 2>/dev/null)
echo "  Диапазон полосы: $RX_A_BW"
RX_A_ANT=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/rx_frontends/A/antenna/options 2>/dev/null)
echo "  Антенны: $RX_A_ANT"
echo ""

# RX Frontend B
echo "📻 RX FRONTEND B (Приёмник, канал 2):"
RX_B_FREQ=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/rx_frontends/B/freq/range 2>/dev/null)
echo "  Диапазон частот: $RX_B_FREQ"
RX_B_GAIN=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/rx_frontends/B/gains/PGA/range 2>/dev/null)
echo "  Диапазон усиления: $RX_B_GAIN"
RX_B_BW=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/rx_frontends/B/bandwidth/range 2>/dev/null)
echo "  Диапазон полосы: $RX_B_BW"
echo ""

# DSP
echo "⚙️  DSP (Цифровая обработка сигналов):"
RX_DSP_RATE=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/rx_dsps/0/rate/range 2>/dev/null)
echo "  RX Sample Rate: $RX_DSP_RATE"
TX_DSP_RATE=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/tx_dsps/0/rate/range 2>/dev/null)
echo "  TX Sample Rate: $TX_DSP_RATE"
RX_DSP_FREQ=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/rx_dsps/0/freq/range 2>/dev/null)
echo "  RX DSP Freq Offset: $RX_DSP_FREQ"
TX_DSP_FREQ=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/tx_dsps/0/freq/range 2>/dev/null)
echo "  TX DSP Freq Offset: $TX_DSP_FREQ"
echo ""

# Синхронизация
echo "🕐 СИНХРОНИЗАЦИЯ:"
TICK_RATE=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/tick_rate 2>/dev/null)
echo "  Tick Rate: $TICK_RATE Hz"
TICK_RANGE=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/tick_rate/range 2>/dev/null)
echo "  Tick Rate Range: $TICK_RANGE"
CLK_SRC=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/clock_source/options 2>/dev/null)
echo "  Clock sources: $CLK_SRC"
CLK_CUR=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/clock_source/value 2>/dev/null)
echo "  Current clock: $CLK_CUR"
TIME_SRC=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/time_source/options 2>/dev/null)
echo "  Time sources: $TIME_SRC"
TIME_CUR=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/time_source/value 2>/dev/null)
echo "  Current time: $TIME_CUR"
echo ""

# Фильтры TX
echo "🔧 TX ФИЛЬТРЫ (Frontend A):"
echo "  FIR_1: $(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/tx_frontends/A/filters/FIR_1/value 2>/dev/null)"
echo "  HB_1: $(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/tx_frontends/A/filters/HB_1/value 2>/dev/null)"
echo "  HB_2: $(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/tx_frontends/A/filters/HB_2/value 2>/dev/null)"
echo "  HB_3: $(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/tx_frontends/A/filters/HB_3/value 2>/dev/null)"
echo "  INT_3: $(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/tx_frontends/A/filters/INT_3/value 2>/dev/null)"
echo "  LPF_BB: $(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/tx_frontends/A/filters/LPF_BB/value 2>/dev/null)"
echo "  LPF_SECONDARY: $(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/tx_frontends/A/filters/LPF_SECONDARY/value 2>/dev/null)"
echo ""

# Фильтры RX
echo "🔧 RX ФИЛЬТРЫ (Frontend A):"
echo "  FIR_1: $(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/rx_frontends/A/filters/FIR_1/value 2>/dev/null)"
echo "  HB_1: $(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/rx_frontends/A/filters/HB_1/value 2>/dev/null)"
echo "  HB_2: $(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/rx_frontends/A/filters/HB_2/value 2>/dev/null)"
echo "  HB_3: $(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/rx_frontends/A/filters/HB_3/value 2>/dev/null)"
echo "  DEC_3: $(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/rx_frontends/A/filters/DEC_3/value 2>/dev/null)"
echo "  LPF_BB: $(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/rx_frontends/A/filters/LPF_BB/value 2>/dev/null)"
echo "  LPF_TIA: $(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/rx_frontends/A/filters/LPF_TIA/value 2>/dev/null)"
echo ""

# Сенсоры
echo "🌡️  СЕНСОРЫ:"
echo "  ref_locked: $(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/sensors/ref_locked 2>/dev/null)"
echo ""

# AGC
echo "⚡ AGC (Автоматическая регулировка усиления):"
RX_A_AGC=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/rx_frontends/A/gain/agc/mode/options 2>/dev/null)
echo "  RX A AGC режимы: $RX_A_AGC"
RX_B_AGC=$(uhd_usrp_probe --args="$ARGS" --string=/mboards/0/dboards/A/rx_frontends/B/gain/agc/mode/options 2>/dev/null)
echo "  RX B AGC режимы: $RX_B_AGC"
echo ""

echo "=================================================="
echo "  Для полного дерева параметров используйте:"
echo "  uhd_usrp_probe --args=\"serial=$SERIAL\" --tree"
echo "=================================================="
