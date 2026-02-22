//+------------------------------------------------------------------+
//|                                             ForexBotPro_v7.1    |
//|                     PROFESSIONAL TRADING EXPERT ADVISOR v7.1    |
//|                 Neural Network + Market Maker + Adaptive Learn   |
//|                                                                  |
//|                     © 2024-2026 ForexBotPro Inc.                |
//|                    All Rights Reserved | Proprietary            |
//+------------------------------------------------------------------+
//|                                                                  |
//| CORE MODULES ARCHITECTURE:                                      |
//|─────────────────────────────────────────────────────────────── |
//| [1] NeuralNetwork.mqh       | 42-input prediction engine       |
//| [2] TDI.mqh                 | Traders Dynamic Index (RSI+EMA)  |
//| [3] CandlePatterns.mqh      | Pin bars, engulfing, inside bars |
//| [4] ChartPatterns.mqh       | M-tops, W-bottoms, H&S patterns  |
//| [5] SupportResistance.mqh   | Pivot-based S/R levels          |
//| [6] MarketAlignment.mqh     | Multi-timeframe alignment (MTF)  |
//| [7] MarketMakerAnalysis.mqh | MMM methodology (Impulse-Pause)  |
//| [8] PositionManager.mqh     | Trade entry/exit/trailing logic  |
//| [9] MultiPairScanner.mqh    | Multi-asset opportunity scanner  |
//| [10] AdaptiveLearning.mqh   | Pattern learning + persistence   |
//| [11] DynamicRiskCalculator  | Intelligent SL/TP calculation    |
//| [12] AdaptiveLearningV2.mqh | Advanced auto-learning (v7.1)    |
//+------------------------------------------------------------------+
#property copyright "© 2024-2026 ForexBotPro Inc. | All Rights Reserved"
#property version   "7.1"
#property description "ForexBotPro v7.1: Neural Network + Market Maker + Adaptive Learning"
#property strict
//+------------------------------------------------------------------+
//| INCLUDE MODULES (In Proper Dependency Order)                    |
//+------------------------------------------------------------------+
#include <ForexBotPro\Enums.mqh>
#include <ForexBotPro\ProfessionalDashboard.mqh>
#include <ForexBotPro\MarketMakerAnalysis.mqh>
#include <ForexBotPro\NeuralNetwork.mqh>
#include <ForexBotPro\TDI.mqh>
#include <ForexBotPro\CandlePatterns.mqh>
#include <ForexBotPro\ChartPatterns.mqh>
#include <ForexBotPro\SupportResistance.mqh>
#include <ForexBotPro\MarketAlignment.mqh>
#include <ForexBotPro\PositionManager.mqh>
#include <ForexBotPro\MultiPairScanner.mqh>
#include <ForexBotPro\AdaptiveLearning.mqh>
#include <ForexBotPro\DynamicRiskCalculator.mqh>
#include <ForexBotPro\AdaptiveLearningV2.mqh>
#include <ForexBotPro\CompoundInterestV2.mqh>
#include <ForexBotPro\VisualPatterns.mqh>
//+------------------------------------------------------------------+
//| EXPERT ADVISOR PARAMETERS                                        |
//+------------------------------------------------------------------+
input group "┌─ GENERAL CONFIGURATION"
input ulong InpMagicNumber = 123456;               // Magic number for trade tracking
input ENUM_TIMEFRAMES InpPrimaryTF = PERIOD_M15;   // Primary analysis timeframe
input ENUM_TIMEFRAMES InpSecondaryTF = PERIOD_H1; // Secondary timeframe (MTF)
input bool InpUseH1TrendFilter = true;
input double InpSLTightenOnH1Align = 0.85;
input int InpScanInterval = 60;                    // Scanner interval (seconds)
input int InpGMTOffset = 0;                        // GMT offset for session detection
input group "┌─ TRADING MODE"
input bool InpMultiPairMode = true;                // Enable multi-pair scanning
input string InpSymbols = "EURUSD,GBPUSD,USDJPY,USDCHF,AUDUSD,NZDUSD,USDCAD,EURGBP,EURJPY,GBPJPY";
input bool InpUseDefaultPairs = true;              // Use built-in symbol list
input group "┌─ CHART & VISUALIZATION"
input string InpTemplateName = "";                 // Template name to load
input bool InpOpenChartsOnSignal = false;          // Auto-open charts on signals
input bool InpShowPanel = true;                    // Display stats panel
input group "┌─ RISK MANAGEMENT (Static)"
input double InpLotSize = 0.01;                    // Base lot size
input double InpStopLossPips = 15.0;               // Base stop loss (pips)
input double InpTakeProfitPips = 45.0;             // Base take profit (pips)
input int InpMaxPositions = 3;                     // Maximum concurrent positions
input double InpMaxSpreadPips = 2.5;               // Maximum allowed spread
input group "┌─ DYNAMIC RISK CALCULATOR"
input bool InpDynamicRiskEnabled = true;           // Enable dynamic SL/TP
input bool InpDynamicSLEnabled = true;             // Enable dynamic stop loss
input bool InpUseATRVolatility = true;             // Adjust for volatility (ATR)
input double InpATRMultiplier = 1.0;               // ATR adjustment multiplier
input bool InpUseSessionMultiplier = true;         // Adjust for trading session
input bool InpUseMMPhaseMultiplier = true;         // Adjust for MMM cycle phase
input bool InpUseKillZoneFilter = true;            // Respect kill zone levels
input double InpRRRatio = 3.0;                     // Risk/Reward ratio (TP/SL)
input bool InpUseImpulseMultiplier = true;         // Adjust for impulse strength
input double InpMinSLPips = 12.0;                  // Minimum SL (hard floor)
input double InpMaxSLPips = 45.0;                  // Maximum SL (hard ceiling)
input group "┌─ TRAILING STOP"
input bool InpTrailingEnabled = true;              // Enable trailing stop
input double InpTrailingActivationPips = 200;      // Activate after X pips profit
input double InpTrailingStopPips = 150;            // Trailing distance (pips)
input double InpTrailingStepPips = 100;             // Step size (pips)
input group "┌─ PROTECTION MECHANISMS"
input bool InpProfitProtection = true;             // Enable breakeven protection
input double InpBreakEvenActivationPips = 150;     // Activate breakeven at X profit
input double InpBreakevenTrigger = 1.0;            // Breakeven trigger multiplier
input double InpBreakevenBuffer = 5.0;             // Breakeven buffer pips
input bool InpMTFMonitoring = true;                // Monitor higher timeframes
input bool InpCloseLossOnMTFMisalign = false;      // Close on MTF misalignment
input int InpMaxMisalignments = 8;                 // Max misaligned candles
input group "┌─ DYNAMIC POSITION DURATION"
input bool InpDynamicDuration = true;              // Enable smart exit timing
input double InpMinHoldScorePercent = 70.0;        // Minimum confidence to hold
input bool InpCloseOnScoreDrop = true;             // Close if score drops
input int InpScoreDropBars = 3;                    // Bars to detect drop
input bool InpUseMMCycleExit = true;               // Exit on MMM cycle shift
input group "┌─ COMPOUND INTEREST & SCALING"
input bool InpCompoundEnabled = true;              // Enable lot auto-scaling
input double InpInitialCapital = 10.0;             // Initial account size (USD)
input double InpCompoundFactor = 1.05;             // Scale factor (5% per win)
input group "┌─ THREE-THRESHOLD SYSTEM"
input double InpIAWeight = 0.30;                   // Neural Network weight (30%)
input double InpTechnicalWeight = 0.35;            // Technical analysis weight (35%)
input double InpAlignmentWeight = 0.35;            // Market alignment weight (35%)
input double InpMinConfidenceLevel = 78.0;         // Minimum confidence threshold
input bool InpRequireAllThresholds = true;         // All signals must align
input group "┌─ NEURAL NETWORK SETTINGS"
input bool InpUseNeuralNetwork = true;             // Enable ML predictions
input int InpNNHiddenLayer1 = 128;                 // Hidden layer 1 neurons
input int InpNNHiddenLayer2 = 64;                  // Hidden layer 2 neurons
input int InpNNHiddenLayer3 = 32;                  // Hidden layer 3 neurons
input double InpNNLearningRate = 0.001;            // Base learning rate
input bool InpNNPostPredictionFilter = true;       // Apply validation filtering
input bool InpTrainNNOnInit = true;
input int InpNNTrainDays = 180;
input int InpNNTrainEpochs = 30;
input double InpNNTrainLearningRate = 0.001;
input double InpNNTargetAccuracy = 75.0;
input int InpNNTrainMaxEpochs = 150;
input int InpNNTrainMaxAttempts = 3;
input bool InpNNBalanceLabels = true;
input double InpMinIAScore = 60.0;
input group "┌─ ENTRENAMIENTO ASIA LUNES"
input bool InpFocusMondayAsia = true;
input int InpAsiaStartHour = 0;
input int InpAsiaEndHour = 8;
input double InpMondayAsiaWeight = 2.0;
input group "┌─ CIERRE SEMANAL"
input bool InpCloseFridayEnabled = true;
input int InpFridayCloseHour = 16;
input int InpFridayCloseMinute = 0;
input group "┌─ MARKET MAKER METHODOLOGY"
input bool InpUseMMM = true;                       // Enable MMM analysis
input bool InpDetectImpulsePause = true;           // Detect impulse/pause cycles
input bool InpAnalyzeCyclePower = true;            // Analyze impulse strength
input bool InpRespectKillZones = true;             // Respect session kill zones
input ENUM_MMM_SESSION InpSessionMode = MMM_SESSION_ADAPTIVE;
input bool InpShowMMAnalysis = true;               // Display MMM indicators
input group "┌─ PATTERN RECOGNITION"
input bool InpUseCandlePatterns = true;            // Detect candle patterns
input bool InpUseChartPatterns = true;             // Detect chart patterns
input bool InpUseSupportResistance = true;         // Use S/R analysis
input bool InpUseVisualPatterns = true;            // Use visual pattern detection
input group "┌─ TECHNICAL ANALYSIS"
input bool InpUseTDI = true;                       // Enable TDI (RSI+EMA)
input int InpTDIRSIPeriod = 13;                    // TDI RSI period
input int InpTDIEmaPeriod = 34;                    // TDI EMA period
input int InpTDIMomentumPeriod = 34;               // TDI momentum period
input bool InpUseMarketAlignment = true;           // Enable EMA alignment
input int InpEMA50Period = 50;                     // EMA 50 for fast alignment
input int InpEMA200Period = 200;                   // EMA 200 for trend
input group "┌─ ADAPTIVE LEARNING"
input bool InpUseAdaptiveLearning = true;          // Enable learning system
input bool InpUseAdaptiveLearningV2 = true;        // Enable V2 advanced learning
input bool InpAutoAdjustWeights = true;            // Auto-adjust module weights
input bool InpPersistLearningData = true;          // Save learning data
input int InpMinTradesForValidation = 10;          // Min trades for pattern validation
input double InpMinPatternWinRate = 0.65;          // Min 65% win rate for patterns
input bool InpApplyNNFeedback = true;              // Feedback to neural network
input double InpAdaptiveLearningRate = 0.01;       // Max learning rate
input double InpMinPatternSimilarity = 60.0;
input group "┌─ PERFORMANCE MONITORING"
input bool InpEnableProfitTracking = true;         // Track profit metrics
input bool InpEnableDrawdownTracking = true;       // Track drawdown limits
input double InpMaxDrawdownPercent = 10.0;         // Max drawdown (10%)
input bool InpEnableStatisticsExport = false;      // Export stats to file
input bool InpDebugMode = false;                   // Enable debug logging
input group "=== PROFESSIONAL DASHBOARD ==="
input bool InpShowProfessionalDashboard = true;    // Enable professional dashboard
input ENUM_DASHBOARD_THEME InpDashboardTheme = THEME_DARK_PROFESSIONAL;
input int InpDashboardX = -510;                    // X position (negative = from right)
input int InpDashboardY = 30;                      // Y position
input int InpDashboardWidth = 300;                 // Width (pixels)
input int InpDashboardHeight = 520;                // Height (pixels)
input bool InpShowPerfSection = true;              // Show performance metrics
input bool InpShowTradingSection = true;           // Show trading status
input bool InpShowStatsSection = true;             // Show cumulative statistics
input int InpDashboardRefreshMs = 500;             // Refresh rate (milliseconds)
//+------------------------------------------------------------------+
//| DEPRECATED PARAMETERS (Legacy Support)                          |
//+------------------------------------------------------------------+
input double InpMinConfidence = 85.0;              // [DEPRECATED]
input int InpTDI_RSI_Period = 13;                  // [DEPRECATED]
input int InpTDI_Price_Period = 2;                 // [DEPRECATED]
input int InpTDI_Signal_Period = 7;                // [DEPRECATED]
input int InpTDI_Volatility_Band = 34;             // [DEPRECATED]
input int InpEMA_Fast = 21;                        // [DEPRECATED]
input int InpEMA_Slow = 50;                        // [DEPRECATED]
input int InpEMA_Trend = 200;                      // [DEPRECATED]
input int InpEMA_Macro = 800;                      // [DEPRECATED]
input bool InpRequireEMAAlignment = true;          // [DEPRECATED]
input bool InpRequireMTFAlignment = true;          // [DEPRECATED]
input bool InpRequirePatternConfirmation = true;   // [DEPRECATED]
input bool InpAutoTrade = true;                    // [DEPRECATED]
input bool InpAdaptiveLearning = true;             // [DEPRECATED]
input bool InpUsePatternBoost = true;              // [DEPRECATED]
input bool InpUseMarketMaker = true;               // [DEPRECATED]
input double InpMMWeight = 0.25;                   // [DEPRECATED]
input bool InpRequireStopHunt = true;             // [DEPRECATED]
input bool InpRequireKillZone = true;              // [DEPRECATED]
input bool InpVisualPatterns = true;               // [DEPRECATED]
input int InpMWLookback = 100;                     // [DEPRECATED]
input int InpMWPivotStrength = 5;                  // [DEPRECATED]
input double InpRetracementMin = 0.382;            // [DEPRECATED]
input double InpRetracementMax = 0.786;            // [DEPRECATED]
input group "┌─ TELEGRAM NOTIFICATIONS"
input bool InpTelegramEnabled = true;             // Enable Telegram alerts
input string InpTelegramToken = "8068264650:AAHCVMObE49qsz0B20haVDVgXWcnlrIiZfw";                // Telegram bot token
input string InpTelegramChatId = "7770112666";               // Telegram chat ID
input string InpTelegramChannel = "Forex Bot Pro v7.1 | Señales Premium";
input int InpTelegramUpdateSec = 300;              // Update interval (seconds)
#include <ForexBotPro\TelegramNotifier.mqh>

input group "┌─ STRATEGY 2: TRIANGULAR ARBITRAGE + IA"
input bool InpEnableArbitrageStrategy = true;      // Enable secondary arbitrage strategy
input string InpArbTriangle = "EURUSD,GBPUSD,EURGBP"; // Triangle symbols A,B,C
input ulong InpArbMagicNumber = 223456;            // Magic number for arbitrage strategy
input double InpArbBaseLot = 0.01;                 // Base lot for A and B legs
input double InpArbMinEdgePips = 0.4;              // Min edge threshold (pips equivalent)
input double InpArbTakeProfit = 2.0;               // Basket TP in account currency
input double InpArbStopLoss = 4.0;                 // Basket SL in account currency
input int InpArbMaxHoldSeconds = 120;              // Max basket hold time
//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTDIIndicator g_tdi;
CCandlePatternDetector g_candleDetector;
CChartPatternDetector g_chartDetector;
CSupportResistanceAnalyzer g_srAnalyzer;
CNeuralNetwork g_neuralNet;
CMarketAlignment g_alignment;
CPositionManager g_positionManager;
CMultiPairScanner g_scanner;
CAdaptiveLearning g_adaptiveLearning;
CMarketMakerAnalysis g_marketMaker;
CVisualPatternDetector g_visualPatterns;
CTelegramNotifier g_telegram;
CCompoundInterestV2 g_compoundInterest;
CProfessionalDashboard g_dashboard;
datetime g_lastScanTime = 0;
TradeFeatureSnapshot g_tradeContextMap[];
ulong g_tradeContextTickets[];
int g_tradeContextCount = 0;
TradeFeatureSnapshot g_pendingContextMap[];
ulong g_pendingOrderTickets[];
int g_pendingContextCount = 0;
bool g_initialized = true;
string g_openedCharts[];
int g_openedChartsCount = 0;
ulong g_lastCheckedTickets[];
int g_lastCheckedCount = 0;

string g_arbSymA = "";
string g_arbSymB = "";
string g_arbSymC = "";
bool g_arbBasketOpen = false;
int g_arbDirection = 0; // 1 buy-cycle, -1 sell-cycle
datetime g_arbOpenTime = 0;

bool InitArbitrageStrategy();
bool ParseArbTriangle(string tri,string &a,string &b,string &c);
void ProcessArbitrageStrategy();
bool HasArbPositions();
double GetArbBasketProfit();
void CloseArbBasket(string reason);
bool SendArbOrder(string symbol, ENUM_ORDER_TYPE orderType, double lot, string comment);
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== Forex Bot Pro v7.1 Iniciando ===");
   Print("Modo: ", InpMultiPairMode ? "Multi-Par" : "Par Único");
   Print("Primary TF: ", EnumToString(InpPrimaryTF));
   Print("Min Confidence: ", InpMinConfidenceLevel, "%");
   
   // Initialize Position Manager
   g_positionManager.Init(InpMagicNumber, InpStopLossPips, InpTakeProfitPips,
      InpTrailingActivationPips, InpTrailingStopPips, InpTrailingStepPips,
      InpInitialCapital, InpLotSize);
   g_positionManager.SetTrailingEnabled(InpTrailingEnabled);
   g_positionManager.SetProfitProtection(InpProfitProtection);
   g_positionManager.SetBreakEvenActivation(InpBreakEvenActivationPips);
   g_positionManager.SetCompoundEnabled(InpCompoundEnabled);
   g_positionManager.SetMTFMonitorEnabled(InpMTFMonitoring);
   g_positionManager.SetCloseLossOnMTFMisalign(InpCloseLossOnMTFMisalign);
   g_positionManager.SetMaxMisalignmentCount(InpMaxMisalignments);
   g_positionManager.SetDynamicSLEnabled(InpDynamicSLEnabled);
   g_positionManager.SetATRMultiplier(InpATRMultiplier);
   g_positionManager.SetMinMaxSLPips(InpMinSLPips, InpMaxSLPips);
   g_positionManager.SetRRRatio(InpRRRatio);
   g_positionManager.SetBreakevenParams(InpBreakevenTrigger, InpBreakevenBuffer);
   
   // Initialize CompoundInterest
   g_compoundInterest.SetInitialCapital(AccountInfoDouble(ACCOUNT_BALANCE));
   g_compoundInterest.SetBaseLot(InpLotSize);
   g_compoundInterest.SetCompoundEnabled(InpCompoundEnabled);
   
   g_positionManager.SetDynamicDuration(InpDynamicDuration, InpMinHoldScorePercent,
      InpCloseOnScoreDrop, InpScoreDropBars, InpUseMMCycleExit);
   g_positionManager.SetScoreWeights(InpIAWeight, InpTechnicalWeight, InpAlignmentWeight);
   
   // Initialize Multi-Pair Scanner
   if(InpMultiPairMode)
   {
      g_scanner.Init(InpPrimaryTF, InpSecondaryTF, InpMinConfidenceLevel);
      g_scanner.SetMagicNumber(InpMagicNumber);
      g_scanner.SetMarketMakerParams(InpUseMarketMaker, InpMMWeight, InpGMTOffset);
      
      if(InpUseDefaultPairs)
      {
         g_scanner.AddDefaultPairs();
      }
      else
      {
         // CORRECCIÓN PRINCIPAL: Sintaxis correcta de StringSplit (línea 455)
         string symbols[];
         int count = StringSplit(InpSymbols, ',', symbols);  // ✅ CORREGIDO: ',' en lugar de StringGetCharacter()
         
         for(int i = 0; i < count; i++)
         {
            StringTrimLeft(symbols[i]);
            StringTrimRight(symbols[i]);
            if(StringLen(symbols[i]) > 0)
            {
               if(!g_scanner.AddSymbol(symbols[i]))
                  g_scanner.AddSymbol(symbols[i] + "m");
            }
         }
      }
      
//       if(InpShowPanel)
//          g_scanner.CreatePanel();
      
      Print("Scanner inicializado con ", g_scanner.GetSymbolCount(), " pares");
   }
   else
   {
      // Initialize Single Pair Modules
      g_tdi.Init(_Symbol, InpPrimaryTF, InpTDI_RSI_Period, InpTDI_Price_Period,
         InpTDI_Signal_Period, InpTDI_Volatility_Band);
      g_candleDetector.Init(_Symbol, InpPrimaryTF);
      g_chartDetector.Init(_Symbol, InpPrimaryTF, 100);
      g_srAnalyzer.Init(_Symbol, InpPrimaryTF, 100);
      g_neuralNet.Init(_Symbol, InpPrimaryTF);
      if(InpUseNeuralNetwork && InpTrainNNOnInit)
         g_neuralNet.TrainFromHistory(_Symbol, InpPrimaryTF, InpNNTrainDays, InpNNTrainEpochs,
            InpNNTrainLearningRate, InpNNTargetAccuracy, InpNNTrainMaxEpochs, InpNNTrainMaxAttempts,
            InpNNBalanceLabels, InpGMTOffset, InpFocusMondayAsia, InpAsiaStartHour, InpAsiaEndHour,
            InpMondayAsiaWeight);
      g_alignment.Init(_Symbol, InpPrimaryTF, InpSecondaryTF, InpEMA_Fast, InpEMA_Slow, InpEMA_Trend, InpEMA_Macro);
      Print("Symbol: ", _Symbol);
   }
   

   // Ensure neural network is available for parallel arbitrage strategy in multi-pair mode
   if(InpEnableArbitrageStrategy && InpMultiPairMode)
   {
      g_neuralNet.Init(_Symbol, InpPrimaryTF, InpGMTOffset);
      if(InpUseNeuralNetwork && InpTrainNNOnInit)
         g_neuralNet.TrainFromHistory(_Symbol, InpPrimaryTF, InpNNTrainDays, InpNNTrainEpochs,
            InpNNTrainLearningRate, InpNNTargetAccuracy, InpNNTrainMaxEpochs, InpNNTrainMaxAttempts,
            InpNNBalanceLabels, InpGMTOffset, InpFocusMondayAsia, InpAsiaStartHour, InpAsiaEndHour,
            InpMondayAsiaWeight);
   }

   // Initialize Market Maker
   if(InpUseMarketMaker)
   {
      g_marketMaker.Initialize(_Symbol, InpPrimaryTF, InpGMTOffset);
      Print("Market Maker Method: ACTIVADO");
   }
   
   // Initialize Visual Patterns
   if(InpVisualPatterns)
   {
      g_visualPatterns.Init(_Symbol, InpPrimaryTF, InpMWLookback, InpMWPivotStrength);
      g_visualPatterns.SetRetracementLevels(InpRetracementMin, InpRetracementMax);
      g_visualPatterns.SetDrawingEnabled(true);
      Print("M/W Visual Patterns: ACTIVADO");
   }
   
   // Initialize Adaptive Learning
   if(InpAdaptiveLearning)
   {
      g_adaptiveLearning.Init();
      Print("Aprendizaje Adaptativo: ACTIVADO");
      Print("Patrones de Referencia: ", g_adaptiveLearning.GetPatternCount());
   }
   
   // Initialize Telegram
   if(InpTelegramEnabled && InpTelegramToken != "" && InpTelegramChatId != "")
   {
      g_telegram.Initialize(InpTelegramToken, InpTelegramChatId, InpGMTOffset);
      g_telegram.SetChannelName(InpTelegramChannel);
      g_telegram.SetUpdateInterval(InpTelegramUpdateSec);
      Print("Telegram Notificaciones: ACTIVADO");
   }
   
   // Initialize Professional Dashboard
   if(InpShowProfessionalDashboard)
   {
      int dashboardX = -InpDashboardWidth;
      g_dashboard.Initialize(ChartID(), dashboardX, InpDashboardY, InpDashboardTheme);
      g_dashboard.SetSize(InpDashboardWidth, InpDashboardHeight);
      g_dashboard.SetSections(InpShowPerfSection, InpShowTradingSection, InpShowStatsSection);
      g_dashboard.SetUpdateInterval(InpDashboardRefreshMs);
      Print("Professional Dashboard: ACTIVADO");
   }
   
   InitArbitrageStrategy();

   g_initialized = true;
   Print("=== Inicialización Completa ===");
   EventSetTimer(InpScanInterval);
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   
   if(InpShowProfessionalDashboard)
   {
      g_dashboard.Cleanup();
      Print("Professional Dashboard: LIMPIADO");
   }
   
   if(InpMultiPairMode)
//       g_scanner.DeletePanel();
   
   if(InpVisualPatterns)
      g_visualPatterns.ClearAllPatterns();
   
   Print("=== Forex Bot Pro v7.1 Detenido ===");
   Print("Razón: ", reason);
   Print("Total Trades: ", g_positionManager.GetTotalTrades());
   Print("Win Rate: ", DoubleToString(g_positionManager.GetWinRate(), 1), "%");
   Print("Total Profit: ", DoubleToString(g_positionManager.GetTotalProfit(), 2));
   
   if(InpAdaptiveLearning)
   {
      Print("=== Estadísticas de Aprendizaje ===");
      Print("Trades Registrados: ", g_adaptiveLearning.GetHistoryCount());
      Print("Patrones de Referencia: ", g_adaptiveLearning.GetPatternCount());
      Print("Win Rate Adaptativo: ", DoubleToString(g_adaptiveLearning.GetOverallWinRate(), 1), "%");
      g_adaptiveLearning.ExportLearningData();
   }
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_initialized) return;
   
   // Update compound interest system
   g_compoundInterest.UpdateCapitalFromAccount();
   
   // Manage all open positions
   g_positionManager.ManagePositions();
   
   // Telegram notifications
   if(g_telegram.IsEnabled())
   {
      g_telegram.OnTick();
      CheckTradeClosures();
   }
   
   // Update Professional Dashboard
   if(InpShowProfessionalDashboard)
   {
      // Recalculate position on chart resize
      static long lastChartWidth = 0;
      long currentChartWidth = ChartGetInteger(ChartID(), CHART_WIDTH_IN_PIXELS);
      if(currentChartWidth != lastChartWidth)
      {
         g_dashboard.RecalculatePosition();
         lastChartWidth = currentChartWidth;
      }
      
      if(g_dashboard.NeedsUpdate())
      {
         UpdateProfessionalDashboard();
         g_dashboard.Draw();
         ChartRedraw(ChartID());
      }
   }
   
   // Parallel secondary strategy: triangular arbitrage
   ProcessArbitrageStrategy();

   // Single pair mode
   if(!InpMultiPairMode)
   {
      static datetime lastMonitorUpdate = 0;
      if(TimeCurrent() - lastMonitorUpdate >= 60)
      {
         RefreshSinglePairMonitors();
         lastMonitorUpdate = TimeCurrent();
      }
      
      if(TimeCurrent() - g_lastScanTime < (long)InpScanInterval) return;
      g_lastScanTime = TimeCurrent();
      
      if(!CheckTradingConditions(_Symbol)) return;
      AnalyzeAndTradeSingle();
   }
}
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!g_initialized) return;
   
   if(InpMultiPairMode)
   {
      g_scanner.ScanAll();
      PrintScanResults();
      RefreshMonitoredPositionScores();
      
      if(InpAutoTrade)
         ProcessMultiPairSignals();
      
      if(InpOpenChartsOnSignal)
         OpenChartsForNewSignals();
   }
}
//+------------------------------------------------------------------+
//| Refresh Single Pair Position Monitors                           |
//+------------------------------------------------------------------+
void RefreshSinglePairMonitors()
{
   for(int j = PositionsTotal() - 1; j >= 0; j--)
   {
      ulong ticket = PositionGetTicket(j);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      int monitorIdx = g_positionManager.FindMonitorIndex(ticket);
      if(monitorIdx < 0)
      {
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         Print("Late monitor registration for ", _Symbol, " ticket ", ticket);
         g_positionManager.RegisterPositionMonitor(ticket, _Symbol, posType, 50, 50, 50);
      }
      
      // Update scores
      g_neuralNet.Predict();
      double iaScore = g_neuralNet.GetIAScore();
      double technicalScore = CalculateTechnicalScore();
      ENUM_SIGNAL_TYPE techSignal = GetTechnicalSignal();
      double alignmentScore = CalculateAlignmentScore(techSignal);
      
      g_positionManager.UpdateSingleMonitorScores(ticket, iaScore, technicalScore, alignmentScore);
      g_positionManager.CheckAndUpdateMTFAlignment(ticket);
      
      // Check dynamic duration
      bool shouldClose = false;
      string closeReason = "";
      if(!g_positionManager.CheckDynamicDuration(ticket, shouldClose, closeReason))
      {
         if(shouldClose)
         {
            Print("Dynamic duration exit (single): ", closeReason);
            g_positionManager.ClosePosition(ticket, closeReason);
            continue;
         }
      }
      
      string status;
      g_positionManager.GetPositionMonitorStatus(ticket, status);
      Print("Monitor [", _Symbol, " #", ticket, "]: ", status);
   }
}
//+------------------------------------------------------------------+
//| Refresh Multi-Pair Position Monitors                            |
//+------------------------------------------------------------------+
void RefreshMonitoredPositionScores()
{
   for(int j = PositionsTotal() - 1; j >= 0; j--)
   {
      ulong ticket = PositionGetTicket(j);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      string posSymbol = PositionGetString(POSITION_SYMBOL);
      int monitorIdx = g_positionManager.FindMonitorIndex(ticket);
      if(monitorIdx < 0)
      {
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         Print("Late monitor registration for ", posSymbol, " ticket ", ticket);
         g_positionManager.RegisterPositionMonitor(ticket, posSymbol, posType, 50, 50, 50);
      }
      
      bool foundInScanner = false;
      for(int i = 0; i < g_scanner.GetSymbolCount(); i++)
      {
         PairAnalysis analysis = g_scanner.GetAnalysis(i);
         if(analysis.symbol == posSymbol)
         {
            g_positionManager.UpdateSingleMonitorScores(ticket, analysis.iaScore,
               analysis.technicalScore, analysis.alignmentScore);
            foundInScanner = true;
            break;
         }
      }
      
      if(!foundInScanner)
      {
         Print("Position ", posSymbol, " not in scanner - running direct analysis");
         g_scanner.AnalyzeSymbol(posSymbol);
         PairAnalysis fallbackAnalysis = g_scanner.GetAnalysisBySymbol(posSymbol);
         if(fallbackAnalysis.symbol == posSymbol && fallbackAnalysis.lastUpdate > 0)
         {
            g_positionManager.UpdateSingleMonitorScores(ticket, fallbackAnalysis.iaScore,
               fallbackAnalysis.technicalScore, fallbackAnalysis.alignmentScore);
         }
         else
         {
            Print("WARNING: Could not analyze symbol ", posSymbol);
         }
      }
      
      g_positionManager.CheckAndUpdateMTFAlignment(ticket);
      
      bool shouldClose = false;
      string closeReason = "";
      if(!g_positionManager.CheckDynamicDuration(ticket, shouldClose, closeReason))
      {
         if(shouldClose)
         {
            Print("Dynamic duration exit: ", closeReason);
            g_positionManager.ClosePosition(ticket, closeReason);
            continue;
         }
      }
      
      string status;
      g_positionManager.GetPositionMonitorStatus(ticket, status);
      Print("Monitor [", posSymbol, " #", ticket, "]: ", status);
   }
}
//+------------------------------------------------------------------+
bool IsFridayCloseTime()
{
   if(!InpCloseFridayEnabled) return false;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = (dt.hour + InpGMTOffset) % 24;
   if(hour < 0) hour += 24;
   
   if(dt.day_of_week != 5) return false;
   if(hour > InpFridayCloseHour) return true;
   if(hour == InpFridayCloseHour && dt.min >= InpFridayCloseMinute) return true;
   return false;
}

void HandleFridayClose()
{
   if(!IsFridayCloseTime()) return;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int dateKey = dt.year * 10000 + dt.mon * 100 + dt.day;
   static int lastCloseKey = 0;
   if(lastCloseKey == dateKey) return;
   
   g_positionManager.CloseAllPositions("Cierre semanal viernes 16:00");
   lastCloseKey = dateKey;
}

//+------------------------------------------------------------------+
void LogBlock(string context, string reason)
{
   if(!InpDebugMode) return;
   Print("[BLOCK] ", context, ": ", reason);
}
//+------------------------------------------------------------------+
//| Check Trading Conditions                                         |
//+------------------------------------------------------------------+
bool CheckTradingConditions(string symbol)
{
   if(IsFridayCloseTime())
   {
      LogBlock(symbol, "viernes cierre");
      return false;
   }
   
   if(g_positionManager.CountPositions() >= InpMaxPositions)
   {
      LogBlock(symbol, "max posiciones");
      return false;
   }
   
   if(g_positionManager.HasPosition(symbol))
   {
      LogBlock(symbol, "ya hay posicion");
      return false;
   }
   
   double pipValue = g_positionManager.GetPipValue(symbol);
   double spread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(pipValue > 0) spread = spread / pipValue;
   
   if(spread > InpMaxSpreadPips)
   {
      LogBlock(symbol, "spread alto");
      return false;
   }
   
   return true;
}
//+------------------------------------------------------------------+
//| Analyze and Trade Single Pair                                   |
//+------------------------------------------------------------------+
void AnalyzeAndTradeSingle()
{
   // Get Neural Network prediction
   ENUM_SIGNAL_TYPE nnSignal = g_neuralNet.GetSignalDirection();
   double iaScore = g_neuralNet.GetIAScore();
   
   // Get Technical analysis
   double technicalScore = CalculateTechnicalScore();
   ENUM_SIGNAL_TYPE technicalSignal = GetTechnicalSignal();
   
   // Get alignment data
   TDIResult tdiResult = g_tdi.Calculate(100);
   AlignmentResult emaResult = g_alignment.GetEMAAlignment();
   bool mtfAligned = g_alignment.CheckMTFAlignment();
   
   if(InpUseH1TrendFilter && InpSecondaryTF == PERIOD_H1 && !mtfAligned)
   {
      LogBlock(_Symbol, "mtf no alineado");
      return;
   }
   
   // Check visual patterns
   MWPatternData mPattern, wPattern;
   ZeroMemory(mPattern);
   ZeroMemory(wPattern);
   bool hasVisualPattern = true;
   
   if(InpVisualPatterns)
   {
      mPattern = g_visualPatterns.DetectMPattern();
      wPattern = g_visualPatterns.DetectWPattern();
      if(mPattern.isValid || wPattern.isValid)
      {
         hasVisualPattern = true;
         Print("=== M/W Visual Patterns ===");
         Print(g_visualPatterns.GetPatternStatus());
      }
   }
   
   // Adjust technical signal if needed
   if(technicalSignal == SIGNAL_NEUTRAL && nnSignal != SIGNAL_NEUTRAL)
   {
      if(nnSignal == SIGNAL_BUY || nnSignal == SIGNAL_STRONG_BUY)
         technicalSignal = SIGNAL_WEAK_BUY;
      else if(nnSignal == SIGNAL_SELL || nnSignal == SIGNAL_STRONG_SELL)
         technicalSignal = SIGNAL_WEAK_SELL;
   }
   
   // Calculate alignment score
   double alignmentScore = CalculateAlignmentScore(technicalSignal);
   
   // Calculate combined confidence
   double combinedConfidence = (iaScore * InpIAWeight) +
      (technicalScore * InpTechnicalWeight) +
      (alignmentScore * InpAlignmentWeight);
   
   // Apply pattern boost
   double patternBoost = 0;
   string emaAlignStr = emaResult.direction == TREND_BULLISH ? "BULL" :
      (emaResult.direction == TREND_BEARISH ? "BEAR" : "FLAT");
   ENUM_SIGNAL_TYPE finalSignal = GetFinalSignal(technicalSignal, combinedConfidence);
   
   if(InpAdaptiveLearning && InpUsePatternBoost && finalSignal != SIGNAL_NEUTRAL)
   {
      patternBoost = g_adaptiveLearning.GetConfidenceBoost(iaScore, technicalScore, alignmentScore,
         finalSignal, emaAlignStr, mtfAligned);
      if(patternBoost > 0)
      {
         combinedConfidence += patternBoost;
         finalSignal = GetFinalSignal(technicalSignal, combinedConfidence);
         Print(">>> Pattern Boost aplicado: +", DoubleToString(patternBoost, 1), "%");
      }
      combinedConfidence = g_adaptiveLearning.ApplyAdaptiveBias(combinedConfidence);
   }
   
   // Apply M/W pattern boosts
   double mwPatternBoost = 0;
   double candleBoost = 0;
   double aiBoost = 0;
   double srBoost = 0;
   double trendBoost = 0;
   double cycleBoost = 0;
   
   if(InpVisualPatterns && hasVisualPattern)
   {
      bool mwAlignedWithSignal = false;
      
      if((technicalSignal == SIGNAL_SELL || technicalSignal == SIGNAL_STRONG_SELL) && mPattern.isValid)
      {
         mwAlignedWithSignal = true;
         if(mPattern.retracementConfirmed)
         {
            mwPatternBoost = 6.0 + (mPattern.confidence - 70) * 0.1;
            Print(">>> M Pattern con retroceso: +", DoubleToString(mwPatternBoost, 1), "%");
         }
         if(mPattern.candleConfirm.hasConfirmation)
         {
            candleBoost = 5.0 + (mPattern.candleConfirm.confidence - 75) * 0.1;
            Print(">>> ", mPattern.candleConfirm.patternName, " confirma M: +", DoubleToString(candleBoost, 1), "%");
         }
         if(mPattern.srZone.atResistanceZone)
         {
            srBoost = 4.0;
            Print(">>> M Pattern en RESISTENCIA: +", DoubleToString(srBoost, 1), "%");
         }
         if(mPattern.trend.alignedWithPattern)
         {
            trendBoost = 3.0;
            Print(">>> Tendencia alineada SELL: +", DoubleToString(trendBoost, 1), "%");
         }
         if(mPattern.cycle.optimalForEntry)
         {
            cycleBoost = 2.0;
            Print(">>> Ciclo óptimo: +", DoubleToString(cycleBoost, 1), "%");
         }
         if(mPattern.aiPrediction >= 80)
         {
            aiBoost = (mPattern.aiPrediction - 75) * 0.2;
            Print(">>> IA SELL: +", DoubleToString(aiBoost, 1), "%");
         }
      }
      else if((technicalSignal == SIGNAL_BUY || technicalSignal == SIGNAL_STRONG_BUY) && wPattern.isValid)
      {
         mwAlignedWithSignal = true;
         if(wPattern.retracementConfirmed)
         {
            mwPatternBoost = 6.0 + (wPattern.confidence - 70) * 0.1;
            Print(">>> W Pattern con retroceso: +", DoubleToString(mwPatternBoost, 1), "%");
         }
         if(wPattern.candleConfirm.hasConfirmation)
         {
            candleBoost = 5.0 + (wPattern.candleConfirm.confidence - 75) * 0.1;
            Print(">>> ", wPattern.candleConfirm.patternName, " confirma W: +", DoubleToString(candleBoost, 1), "%");
         }
         if(wPattern.srZone.atSupportZone)
         {
            srBoost = 4.0;
            Print(">>> W Pattern en SOPORTE: +", DoubleToString(srBoost, 1), "%");
         }
         if(wPattern.trend.alignedWithPattern)
         {
            trendBoost = 3.0;
            Print(">>> Tendencia alineada BUY: +", DoubleToString(trendBoost, 1), "%");
         }
         if(wPattern.cycle.optimalForEntry)
         {
            cycleBoost = 2.0;
            Print(">>> Ciclo óptimo: +", DoubleToString(cycleBoost, 1), "%");
         }
         if(wPattern.aiPrediction >= 80)
         {
            aiBoost = (wPattern.aiPrediction - 75) * 0.2;
            Print(">>> IA BUY: +", DoubleToString(aiBoost, 1), "%");
         }
      }
      
      double totalBoost = mwPatternBoost + candleBoost + aiBoost + srBoost + trendBoost + cycleBoost;
      if(totalBoost > 0)
      {
         combinedConfidence += totalBoost;
         finalSignal = GetFinalSignal(technicalSignal, combinedConfidence);
      }
   }
   
   // Print analysis
   Print("=== Análisis ", _Symbol, " ===");
   Print("IA Score: ", DoubleToString(iaScore, 1), "%");
   Print("Technical Score: ", DoubleToString(technicalScore, 1), "%");
   Print("Alignment Score: ", DoubleToString(alignmentScore, 1), "%");
   Print("Combined Confidence: ", DoubleToString(combinedConfidence, 1), "%");
   Print("Technical Signal: ", EnumToString(technicalSignal));
   
   if(InpUseNeuralNetwork && InpNNPostPredictionFilter && iaScore < InpMinIAScore)
   {
      Print("IA por debajo del mínimo: ", DoubleToString(iaScore, 1), "% < ", InpMinIAScore, "%");
      LogBlock(_Symbol, "ia minima");
      return;
   }
   
   if(InpAdaptiveLearning && finalSignal != SIGNAL_NEUTRAL)
   {
      double similarity = g_adaptiveLearning.GetPatternSimilarity(iaScore, technicalScore, alignmentScore,
         finalSignal, emaAlignStr, mtfAligned);
      if(similarity > 0 && similarity < InpMinPatternSimilarity)
      {
         Print("Similitud baja con patrones ganadores: ", DoubleToString(similarity, 1), "%");
         LogBlock(_Symbol, "similitud baja");
         return;
      }
   }
   
   if(InpUseMarketMaker && InpUseKillZoneFilter)
   {
      ENUM_KILL_ZONE kz = g_marketMaker.GetKillZone();
      if(kz == KZ_ASIAN || kz == KZ_NONE)
      {
         Print("Kill Zone fuera de sesión óptima");
         LogBlock(_Symbol, "kill zone");
         return;
      }
   }
   
   // Check minimum confidence
   if(combinedConfidence < InpMinConfidenceLevel)
   {
      Print("Confianza insuficiente: ", DoubleToString(combinedConfidence, 1), "% < ", InpMinConfidenceLevel, "%");
      LogBlock(_Symbol, "confianza baja");
      return;
   }
   
   if(technicalSignal == SIGNAL_NEUTRAL)
   {
      Print("Señal neutral - No se abre posición");
      LogBlock(_Symbol, "senal neutral");
      return;
   }
   
   // Check EMA alignment
   if(InpRequireEMAAlignment)
   {
      if(technicalSignal == SIGNAL_BUY || technicalSignal == SIGNAL_STRONG_BUY)
      {
         if(emaResult.direction == TREND_BEARISH)
         {
            Print("EMA no alineada para compra");
            LogBlock(_Symbol, "ema no alineada");
            return;
         }
      }
      else if(technicalSignal == SIGNAL_SELL || technicalSignal == SIGNAL_STRONG_SELL)
      {
         if(emaResult.direction == TREND_BULLISH)
         {
            Print("EMA no alineada para venta");
            LogBlock(_Symbol, "ema no alineada");
            return;
         }
      }
   }
   
   // Check MTF alignment
   if(InpRequireMTFAlignment && !g_alignment.CheckMTFAlignment())
   {
      Print("MTF no alineado - Señal descartada");
      LogBlock(_Symbol, "mtf requerido");
      return;
   }
   
   finalSignal = GetFinalSignal(technicalSignal, combinedConfidence);
   Print("=== SEÑAL APROBADA ===");
   Print("Tipo: ", EnumToString(finalSignal));
   Print("Confianza: ", DoubleToString(combinedConfidence, 1), "%");
   Print("Lote: ", g_positionManager.GetCurrentLot());
   
   // Get Market Maker data
   int killZoneNum = 0;
   int beeKayLevelNum = 0;
   int dayCycleNum = 0;
   
   if(InpUseMarketMaker)
   {
      ENUM_KILL_ZONE kz = g_marketMaker.GetKillZone();
      if(kz == KZ_ASIAN) killZoneNum = 1;
      else if(kz == KZ_LONDON) killZoneNum = 2;
      else if(kz == KZ_LONDON_NYC_OVERLAP) killZoneNum = 3;
      else if(kz == KZ_NEW_YORK) killZoneNum = 4;
      
      ENUM_BEEKAY_LEVEL bkLvl = g_marketMaker.GetCurrentBeeKayLevel();
      if(bkLvl == BEEKAY_LEVEL_1) beeKayLevelNum = 1;
      else if(bkLvl == BEEKAY_LEVEL_2) beeKayLevelNum = 2;
      else if(bkLvl == BEEKAY_LEVEL_3) beeKayLevelNum = 3;
      
      dayCycleNum = g_marketMaker.GetCurrentDayCycle();
   }
   
   double patternTargetPrice = 0.0;
   if(InpUseMarketMaker)
   {
      double patternConfidence = g_marketMaker.GetMWPatternConfidence();
      if(patternConfidence >= 70.0)
         patternTargetPrice = g_marketMaker.GetPatternTargetPrice();
   }
   
   double slMultiplier = 1.0;
   if(InpSecondaryTF == PERIOD_H1 && mtfAligned)
      slMultiplier = InpSLTightenOnH1Align;
   
   // Open position
   ulong ticket = g_positionManager.OpenPosition(_Symbol, finalSignal, combinedConfidence,
      killZoneNum, beeKayLevelNum, dayCycleNum, patternTargetPrice, slMultiplier);
   
   if(ticket > 0)
   {
      Print("Orden ejecutada - Ticket: ", ticket);
      
      ENUM_POSITION_TYPE posType = (finalSignal == SIGNAL_BUY || finalSignal == SIGNAL_STRONG_BUY ||
         finalSignal == SIGNAL_CONFIRMED_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      
      double entryPrice = g_positionManager.GetLastEntryPrice();
      double dynamicSL = g_positionManager.GetLastDynamicSL();
      double dynamicTP = g_positionManager.GetLastDynamicTP();
      
      g_positionManager.RegisterPositionMonitor(ticket, _Symbol, posType, iaScore, technicalScore, alignmentScore,
         dynamicSL, dynamicTP, entryPrice);
      Print("Monitor registered for ticket ", ticket);
      
      // Store adaptive learning context
      if(InpAdaptiveLearning)
      {
         TradeFeatureSnapshot context;
         context.symbol = _Symbol;
         context.signal = finalSignal;
         context.iaScore = iaScore;
         context.technicalScore = technicalScore;
         context.alignmentScore = alignmentScore;
         context.combinedScore = combinedConfidence;
         context.tdiRSI = tdiResult.greenLine;
         context.tdiSignal = tdiResult.redLine;
         context.tdiStatus = tdiResult.signal == SIGNAL_BUY ? "BUY" :
            (tdiResult.signal == SIGNAL_SELL ? "SELL" : "NEUTRAL");
         context.emaAlignment = emaAlignStr;
         context.mtfAligned = mtfAligned;
         context.trendDirection = emaResult.direction == TREND_BULLISH ? "UP" :
            (emaResult.direction == TREND_BEARISH ? "DOWN" : "FLAT");
         
         CandlePatternResult candleRes = g_candleDetector.DetectPattern(10);
         ChartPatternResult chartRes = g_chartDetector.DetectAll();
         context.candlePattern = candleRes.pattern != PATTERN_NONE ? candleRes.name : "---";
         context.chartPattern = chartRes.pattern != CHART_PATTERN_NONE ? chartRes.name : "---";
         
         double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
         double pipVal = g_positionManager.GetPipValue(_Symbol);
         context.spreadPips = pipVal > 0 ? spread / pipVal : spread;
         context.entryTime = TimeCurrent();
         
         StorePendingContext(ticket, context);
      }
      
      // Send Telegram notifications
      if(g_telegram.IsEnabled())
      {
         bool isBuy = (posType == POSITION_TYPE_BUY);
         CandlePatternResult candleRes = g_candleDetector.DetectPattern(10);
         ChartPatternResult chartRes = g_chartDetector.DetectAll();
         string patternName = candleRes.pattern != PATTERN_NONE ? candleRes.name :
            (chartRes.pattern != CHART_PATTERN_NONE ? chartRes.name : "");
         
         string killZone = "";
         if(InpUseMarketMaker)
         {
            ENUM_KILL_ZONE kz = g_marketMaker.GetKillZone();
            if(kz == KZ_ASIAN) killZone = "Asian";
            else if(kz == KZ_LONDON) killZone = "London";
            else if(kz == KZ_NEW_YORK) killZone = "New York";
            else if(kz == KZ_LONDON_NYC_OVERLAP) killZone = "London/NYC Overlap";
         }
         
         g_telegram.SendSignalAlert(_Symbol, isBuy, entryPrice, dynamicSL, dynamicTP,
            iaScore, technicalScore, alignmentScore, combinedConfidence,
            patternName, killZone);
         
         g_telegram.SendTradeConfirmation(ticket, _Symbol, isBuy, entryPrice, dynamicSL, dynamicTP,
            g_positionManager.GetCurrentLot());
         
         g_telegram.SendChartWithLevels(_Symbol, isBuy, entryPrice, dynamicSL, dynamicTP);
      }
      
      // Apply template
      if(InpTemplateName != "")
      {
         long chartId = ChartFirst();
         while(chartId >= 0)
         {
            if(ChartSymbol(chartId) == _Symbol)
            {
               ChartApplyTemplate(chartId, InpTemplateName);
               break;
            }
            chartId = ChartNext(chartId);
         }
      }
   }
}
//+------------------------------------------------------------------+
//| Process Multi-Pair Signals                                      |
//+------------------------------------------------------------------+
void ProcessMultiPairSignals()
{
   if(g_positionManager.CountPositions() >= InpMaxPositions)
   {
      LogBlock("MULTI", "max posiciones");
      return;
   }
   
   PairAnalysis best = g_scanner.GetBestSignal();
   if(best.combinedScore >= InpMinConfidenceLevel && best.signal != SIGNAL_NEUTRAL)
   {
      if(!CheckTradingConditions(best.symbol))
         return;
      
      if(InpUseH1TrendFilter && InpSecondaryTF == PERIOD_H1 && best.mtfStatus != "OK")
      {
         LogBlock(best.symbol, "mtf no alineado");
         return;
      }
   
   if(InpUseMarketMaker && InpUseKillZoneFilter)
   {
      ENUM_KILL_ZONE kz = g_marketMaker.GetKillZone();
      if(kz == KZ_ASIAN || kz == KZ_NONE)
      {
         LogBlock(best.symbol, "kill zone");
         return;
      }
   }
      
      if(InpUseNeuralNetwork && InpNNPostPredictionFilter && best.iaScore < InpMinIAScore)
      {
         LogBlock(best.symbol, "ia minima");
         return;
      }
      
      if(InpAdaptiveLearning)
      {
         double similarity = g_adaptiveLearning.GetPatternSimilarity(best.iaScore, best.technicalScore,
            best.alignmentScore, best.signal, best.emaStatus, best.mtfStatus == "OK");
         if(similarity > 0 && similarity < InpMinPatternSimilarity)
         {
            LogBlock(best.symbol, "similitud baja");
            return;
         }
      }
      
      double adjustedScore = best.combinedScore;
      double patternBoost = 0;
      
      if(InpAdaptiveLearning && InpUsePatternBoost)
      {
         patternBoost = g_adaptiveLearning.GetConfidenceBoost(best.iaScore, best.technicalScore,
            best.alignmentScore, best.signal,
            best.emaStatus, best.mtfStatus == "OK");
         if(patternBoost > 0)
         {
            adjustedScore += patternBoost;
            Print(">>> Pattern Boost aplicado: +", DoubleToString(patternBoost, 1), "%");
         }
         adjustedScore = g_adaptiveLearning.ApplyAdaptiveBias(adjustedScore);
      }
      
      Print("=== EJECUTANDO TRADE EN ", best.symbol, " ===");
      Print("Señal: ", EnumToString(best.signal));
      Print("IA: ", DoubleToString(best.iaScore, 1), "% | Tech: ", DoubleToString(best.technicalScore, 1),
         "% | Align: ", DoubleToString(best.alignmentScore, 1), "%");
      Print("Confianza Total: ", DoubleToString(adjustedScore, 1), "%");
      
      int killZoneNum = 0;
      int beeKayLevelNum = 0;
      int dayCycleNum = 0;
      
      if(InpUseMarketMaker)
      {
         ENUM_KILL_ZONE kz = g_marketMaker.GetKillZone();
         if(kz == KZ_ASIAN) killZoneNum = 1;
         else if(kz == KZ_LONDON) killZoneNum = 2;
         else if(kz == KZ_LONDON_NYC_OVERLAP) killZoneNum = 3;
         else if(kz == KZ_NEW_YORK) killZoneNum = 4;
         
         ENUM_BEEKAY_LEVEL bkLvl = g_marketMaker.GetCurrentBeeKayLevel();
         if(bkLvl == BEEKAY_LEVEL_1) beeKayLevelNum = 1;
         else if(bkLvl == BEEKAY_LEVEL_2) beeKayLevelNum = 2;
         else if(bkLvl == BEEKAY_LEVEL_3) beeKayLevelNum = 3;
         
         dayCycleNum = g_marketMaker.GetCurrentDayCycle();
      }
      
      double slMultiplier = 1.0;
      if(InpSecondaryTF == PERIOD_H1 && best.mtfStatus == "OK")
         slMultiplier = InpSLTightenOnH1Align;
      
      ulong ticket = g_positionManager.OpenPosition(best.symbol, best.signal, adjustedScore,
         killZoneNum, beeKayLevelNum, dayCycleNum, 0.0, slMultiplier);
      
      if(ticket > 0)
      {
         Print("Orden ejecutada - Ticket: ", ticket);
         
         ENUM_POSITION_TYPE posType = (best.signal == SIGNAL_BUY || best.signal == SIGNAL_STRONG_BUY ||
            best.signal == SIGNAL_CONFIRMED_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
         
         double entryPrice = g_positionManager.GetLastEntryPrice();
         double dynamicSL = g_positionManager.GetLastDynamicSL();
         double dynamicTP = g_positionManager.GetLastDynamicTP();
         
         g_positionManager.RegisterPositionMonitor(ticket, best.symbol, posType,
            best.iaScore, best.technicalScore, best.alignmentScore,
            dynamicSL, dynamicTP, entryPrice);
         
         if(g_telegram.IsEnabled())
         {
            bool isBuy = (posType == POSITION_TYPE_BUY);
            string killZone = "";
            if(InpUseMarketMaker)
            {
               ENUM_KILL_ZONE kz = g_marketMaker.GetKillZone();
               if(kz == KZ_ASIAN) killZone = "Asian";
               else if(kz == KZ_LONDON) killZone = "London";
               else if(kz == KZ_NEW_YORK) killZone = "New York";
               else if(kz == KZ_LONDON_NYC_OVERLAP) killZone = "London/NYC Overlap";
            }
            
            g_telegram.SendSignalAlert(best.symbol, isBuy, entryPrice, dynamicSL, dynamicTP,
               best.iaScore, best.technicalScore, best.alignmentScore, adjustedScore,
               best.candlePattern != "---" ? best.candlePattern : best.chartPattern, killZone);
            
            g_telegram.SendTradeConfirmation(ticket, best.symbol, isBuy, entryPrice, dynamicSL, dynamicTP,
               g_positionManager.GetCurrentLot());
            
            g_telegram.SendChartWithLevels(best.symbol, isBuy, entryPrice, dynamicSL, dynamicTP);
         }
         
         if(InpAdaptiveLearning)
         {
            TradeFeatureSnapshot context;
            context.symbol = best.symbol;
            context.signal = best.signal;
            context.iaScore = best.iaScore;
            context.technicalScore = best.technicalScore;
            context.alignmentScore = best.alignmentScore;
            context.combinedScore = adjustedScore;
            context.tdiStatus = best.tdiStatus;
            context.emaAlignment = best.emaStatus;
            context.mtfAligned = (best.mtfStatus == "OK");
            context.candlePattern = best.candlePattern;
            context.chartPattern = best.chartPattern;
            context.trendDirection = best.emaStatus == "BULL" ? "UP" :
               (best.emaStatus == "BEAR" ? "DOWN" : "FLAT");
            context.entryTime = TimeCurrent();
            
            StorePendingContext(ticket, context);
         }
         
         if(InpTemplateName != "")
            g_scanner.ApplyTemplate(best.symbol, InpTemplateName);
      }
   }
   else
   {
      if(InpDebugMode)
      {
         Print("[BLOCK] MULTI: sin señal | score=", DoubleToString(best.combinedScore, 1),
            " | signal=", EnumToString(best.signal));
      }
   }
}
//+------------------------------------------------------------------+
//| Print Scan Results                                               |
//+------------------------------------------------------------------+
void PrintScanResults()
{
   Print("=== ESCANEO MULTI-PAR COMPLETADO ===");
   int signalCount = 0;
   
   for(int i = 0; i < g_scanner.GetSymbolCount(); i++)
   {
      PairAnalysis analysis = g_scanner.GetAnalysis(i);
      if(analysis.combinedScore >= InpMinConfidenceLevel && analysis.signal != SIGNAL_NEUTRAL)
      {
         signalCount++;
         string signalType = "";
         if(analysis.signal == SIGNAL_BUY || analysis.signal == SIGNAL_STRONG_BUY)
            signalType = "COMPRA";
         else if(analysis.signal == SIGNAL_SELL || analysis.signal == SIGNAL_STRONG_SELL)
            signalType = "VENTA";
         
         Print(">>> SEÑAL ", signalType, " en ", analysis.symbol);
         Print("    IA: ", DoubleToString(analysis.iaScore, 1), "% | ",
            "Tech: ", DoubleToString(analysis.technicalScore, 1), "% | ",
            "Align: ", DoubleToString(analysis.alignmentScore, 1), "% | ",
            "TOTAL: ", DoubleToString(analysis.combinedScore, 1), "%");
         Print("    TDI: ", analysis.tdiStatus, " | EMA: ", analysis.emaStatus,
            " | MTF: ", analysis.mtfStatus);
      }
   }
   
   if(signalCount == 0)
      Print("No se encontraron señales por encima del umbral ", InpMinConfidenceLevel, "%");
   else
      Print("Total de señales encontradas: ", signalCount);
}
//+------------------------------------------------------------------+
//| Open Charts for New Signals                                      |
//+------------------------------------------------------------------+
void OpenChartsForNewSignals()
{
   PairAnalysis signals[];
   int count = 0;
   g_scanner.GetSignalsAboveThreshold(signals, count);
   
   if(count > 0)
   {
      for(int i = 0; i < count; i++)
      {
         bool alreadyOpened = false;
         for(int j = 0; j < g_openedChartsCount; j++)
         {
            if(g_openedCharts[j] == signals[i].symbol)
            {
               alreadyOpened = true;
               break;
            }
         }
         
         if(!alreadyOpened)
         {
            long chartId = ChartOpen(signals[i].symbol, InpPrimaryTF);
            if(chartId > 0)
            {
               if(InpTemplateName != "")
                  ChartApplyTemplate(chartId, InpTemplateName);
               
               ArrayResize(g_openedCharts, g_openedChartsCount + 1);
               g_openedCharts[g_openedChartsCount] = signals[i].symbol;
               g_openedChartsCount++;
               Print(">>> Gráfico abierto para ", signals[i].symbol);
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
//| Calculate Technical Score                                        |
//+------------------------------------------------------------------+
double CalculateTechnicalScore()
{
   double score = 50.0;
   int signals = 0;
   
   // TDI Analysis
   TDIResult tdi = g_tdi.Calculate(100);
   if(tdi.signal == SIGNAL_STRONG_BUY || tdi.signal == SIGNAL_STRONG_SELL)
   {
      score += 25;
      signals++;
   }
   else if(tdi.signal == SIGNAL_BUY || tdi.signal == SIGNAL_SELL)
   {
      score += 15;
      signals++;
   }
   
   if(tdi.sharkFinBullish || tdi.sharkFinBearish)
   {
      score += 10;
      Print("TDI Shark Fin detectado: ", tdi.sharkFinBullish ? "Bullish" : "Bearish");
   }
   
   // Support/Resistance
   SRLevels srLevels = g_srAnalyzer.FindLevels();
   g_candleDetector.SetSupportResistance(srLevels.nearestSupport, srLevels.nearestResistance);
   
   // Candle Patterns
   CandlePatternResult candle = g_candleDetector.DetectPattern(10);
   if(candle.pattern != PATTERN_NONE)
   {
      score += (candle.confidence - 50) * 0.3;
      signals++;
      
      string contextStr = "";
      if(candle.nearSupport) contextStr = " [Near Support]";
      if(candle.nearResistance) contextStr = " [Near Resistance]";
      
      Print("Patron de vela detectado: ", candle.name, " (", DoubleToString(candle.confidence, 1), "%)", contextStr);
   }
   
   // Chart Patterns
   ChartPatternResult chart = g_chartDetector.DetectAll();
   if(chart.pattern != CHART_PATTERN_NONE)
   {
      score += (chart.confidence - 50) * 0.4;
      signals++;
      Print("Figura chartista detectada: ", chart.name, " (", DoubleToString(chart.confidence, 1), "%)");
   }
   
   // Breakout Detection
   BreakoutResult breakout = g_srAnalyzer.CheckBreakout();
   if(breakout.detected)
   {
      score += 15;
      signals++;
      Print("Breakout detectado: ", breakout.type, " en ", breakout.level);
   }
   
   // Market Maker Analysis
   if(InpUseMarketMaker)
   {
      g_marketMaker.Analyze();
      double mmScore = g_marketMaker.GetTotalScore();
      int dayCycle = g_marketMaker.GetCurrentDayCycle();
      g_marketMaker.DetectBeeKayReset(tdi.mayoPattern, tdi.blueberryPattern);
      BeeKayLevelState bkLevel = g_marketMaker.GetBeeKayLevelState();
      double levelCoherence = g_marketMaker.GetLevelCycleCoherence();
      
      if(g_marketMaker.IsStopHuntDetected())
      {
         score += 15;
         signals++;
         Print("Market Maker Stop Hunt detectado!");
      }
      
      if(g_marketMaker.GetPattern() != MM_PATTERN_NONE)
      {
         score += 10;
         signals++;
      }
      
      double bkLevelBoost = g_marketMaker.GetBeeKayLevelBoost();
      if(bkLevelBoost != 0)
      {
         score += bkLevelBoost;
         string levelName = "";
         switch(bkLevel.currentLevel)
         {
            case BEEKAY_LEVEL_1: levelName = "Level 1 (MM Driven)"; break;
            case BEEKAY_LEVEL_2: levelName = "Level 2 (Emotional)"; break;
            case BEEKAY_LEVEL_3: levelName = "Level 3 (Profit Taking)"; break;
            default: levelName = "Level 0"; break;
         }
         Print("BeeKay FX: ", levelName, " | Boost: ", DoubleToString(bkLevelBoost, 1));
      }
      
      if(bkLevel.currentLevel == BEEKAY_LEVEL_3)
      {
         Print(">>> ADVERTENCIA: Level 3 - Zona de toma de ganancias");
      }
      
      if(bkLevel.resetDetected)
      {
         Print(">>> BeeKay RESET detectado - Nuevo ciclo iniciado");
         signals++;
         g_marketMaker.ClearBeeKayResetFlag();
      }
      
      if(levelCoherence >= 85.0)
      {
         score += 10;
         signals++;
         Print("Coherencia Nivel-Ciclo: ", DoubleToString(levelCoherence, 1), "% - Alta sincronización");
      }
      
      if(g_marketMaker.IsCycle3EntryAllowed() && bkLevel.currentLevel != BEEKAY_LEVEL_3)
      {
         score += 20;
         signals++;
         MWPatternInfo mInfo = g_marketMaker.GetMPatternInfo();
         MWPatternInfo wInfo = g_marketMaker.GetWPatternInfo();
         
         if(mInfo.detected && mInfo.isSecondLeg && g_marketMaker.IsNearDailyHigh())
         {
            score += mInfo.confidence * 0.3;
            Print(">>> CICLO 3: M Pattern 2da pata - VENTA");
         }
         if(wInfo.detected && wInfo.isSecondLeg && g_marketMaker.IsNearDailyLow())
         {
            score += wInfo.confidence * 0.3;
            Print(">>> CICLO 3: W Pattern 2da pata - COMPRA");
         }
      }
      
      if(g_marketMaker.IsLevel3ExitZone())
      {
         Print(">>> ZONA DE SALIDA: Level 3 + ADR >70%");
      }
      
      score = score * (1.0 - InpMMWeight) + mmScore * InpMMWeight;
      Print("Market Maker: ", g_marketMaker.GetStatusString());
   }
   
   if(signals > 2)
      score += 10;
   
   return MathMax(0, MathMin(100, score));
}
//+------------------------------------------------------------------+
//| Get Technical Signal                                             |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE GetTechnicalSignal()
{
   TDIResult tdi = g_tdi.Calculate(100);
   CandlePatternResult candle = g_candleDetector.DetectPattern(10);
   ChartPatternResult chart = g_chartDetector.DetectAll();
   
   int buySignals = 0;
   int sellSignals = 0;
   
   // TDI signals
   if(tdi.signal == SIGNAL_BUY || tdi.signal == SIGNAL_STRONG_BUY ||
      tdi.signal == SIGNAL_WEAK_BUY || tdi.signal == SIGNAL_MODERATE_BUY)
      buySignals++;
   else if(tdi.signal == SIGNAL_SELL || tdi.signal == SIGNAL_STRONG_SELL ||
      tdi.signal == SIGNAL_WEAK_SELL || tdi.signal == SIGNAL_MODERATE_SELL)
      sellSignals++;
   
   if(tdi.sharkFinBullish)
      buySignals++;
   else if(tdi.sharkFinBearish)
      sellSignals++;
   
   // Candle pattern signals
   if(candle.signal == SIGNAL_BUY || candle.signal == SIGNAL_STRONG_BUY)
      buySignals++;
   else if(candle.signal == SIGNAL_SELL || candle.signal == SIGNAL_STRONG_SELL)
      sellSignals++;
   
   // Chart pattern signals
   if(chart.signal == SIGNAL_BUY || chart.signal == SIGNAL_STRONG_BUY)
      buySignals++;
   else if(chart.signal == SIGNAL_SELL || chart.signal == SIGNAL_STRONG_SELL)
      sellSignals++;
   
   // Breakout signals
   BreakoutResult breakout = g_srAnalyzer.CheckBreakout();
   if(breakout.detected)
   {
      if(breakout.type == "resistance_breakout")
         buySignals++;
      else if(breakout.type == "support_breakout")
         sellSignals++;
   }
   
   // Market Maker signals
   if(InpUseMarketMaker)
   {
      ENUM_SIGNAL_TYPE mmSignal = g_marketMaker.GetMMSignal();
      
      if(g_marketMaker.IsCycle3EntryAllowed())
      {
         MWPatternInfo mInfo = g_marketMaker.GetMPatternInfo();
         MWPatternInfo wInfo = g_marketMaker.GetWPatternInfo();
         
         if(mInfo.detected && mInfo.isSecondLeg && g_marketMaker.IsNearDailyHigh())
         {
            int strength = 0;
            if(mInfo.confidence >= 80.0) strength = 3;
            else if(mInfo.confidence >= 70.0) strength = 2;
            else if(mInfo.confidence >= 60.0) strength = 1;
            
            if(strength > 0)
            {
               sellSignals += strength;
               Print("Market Maker Ciclo 3: M Pattern + Daily High | Confianza: ", DoubleToString(mInfo.confidence, 1));
            }
         }
         if(wInfo.detected && wInfo.isSecondLeg && g_marketMaker.IsNearDailyLow())
         {
            int strength = 0;
            if(wInfo.confidence >= 80.0) strength = 3;
            else if(wInfo.confidence >= 70.0) strength = 2;
            else if(wInfo.confidence >= 60.0) strength = 1;
            
            if(strength > 0)
            {
               buySignals += strength;
               Print("Market Maker Ciclo 3: W Pattern + Daily Low | Confianza: ", DoubleToString(wInfo.confidence, 1));
            }
         }
      }
      else if(mmSignal == SIGNAL_BUY || mmSignal == SIGNAL_STRONG_BUY)
      {
         buySignals += 2;
         Print("Market Maker señal: BUY");
      }
      else if(mmSignal == SIGNAL_SELL || mmSignal == SIGNAL_STRONG_SELL)
      {
         sellSignals += 2;
         Print("Market Maker señal: SELL");
      }
      
      if(InpRequireKillZone)
      {
         ENUM_KILL_ZONE kz = g_marketMaker.GetKillZone();
         if(kz == KZ_ASIAN || kz == KZ_NONE)
         {
            return SIGNAL_NEUTRAL;
         }
      }
      
      if(InpRequireStopHunt && !g_marketMaker.IsStopHuntDetected())
      {
         return SIGNAL_NEUTRAL;
      }
   }
   
   // Determine final signal
   if(buySignals >= 2 && buySignals > sellSignals)
   {
      if(buySignals >= 4)
         return SIGNAL_STRONG_BUY;
      else if(buySignals >= 3)
         return SIGNAL_BUY;
      return SIGNAL_WEAK_BUY;
   }
   else if(sellSignals >= 2 && sellSignals > buySignals)
   {
      if(sellSignals >= 4)
         return SIGNAL_STRONG_SELL;
      else if(sellSignals >= 3)
         return SIGNAL_SELL;
      return SIGNAL_WEAK_SELL;
   }
   
   return SIGNAL_NEUTRAL;
}
//+------------------------------------------------------------------+
//| Calculate Alignment Score                                        |
//+------------------------------------------------------------------+
double CalculateAlignmentScore(ENUM_SIGNAL_TYPE signal)
{
   bool isBuy = (signal == SIGNAL_BUY || signal == SIGNAL_STRONG_BUY ||
      signal == SIGNAL_WEAK_BUY || signal == SIGNAL_MODERATE_BUY ||
      signal == SIGNAL_CONFIRMED_BUY);
   
   return g_alignment.GetAlignmentScore(isBuy);
}
//+------------------------------------------------------------------+
//| Get Final Signal                                                 |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE GetFinalSignal(ENUM_SIGNAL_TYPE techSignal, double confidence)
{
   if(techSignal == SIGNAL_BUY || techSignal == SIGNAL_STRONG_BUY)
   {
      if(confidence >= 92)
         return SIGNAL_CONFIRMED_BUY;
      else if(confidence >= 90)
         return SIGNAL_STRONG_BUY;
      else if(confidence >= 85)
         return SIGNAL_BUY;
      return SIGNAL_MODERATE_BUY;
   }
   else if(techSignal == SIGNAL_SELL || techSignal == SIGNAL_STRONG_SELL)
   {
      if(confidence >= 92)
         return SIGNAL_CONFIRMED_SELL;
      else if(confidence >= 90)
         return SIGNAL_STRONG_SELL;
      else if(confidence >= 85)
         return SIGNAL_SELL;
      return SIGNAL_MODERATE_SELL;
   }
   
   return SIGNAL_NEUTRAL;
}
//+------------------------------------------------------------------+
//| Store Pending Context                                            |
//+------------------------------------------------------------------+
void StorePendingContext(ulong orderTicket, TradeFeatureSnapshot &context)
{
   CleanupStalePendingContexts();
   
   ArrayResize(g_pendingContextMap, g_pendingContextCount + 1);
   ArrayResize(g_pendingOrderTickets, g_pendingContextCount + 1);
   g_pendingContextMap[g_pendingContextCount] = context;
   g_pendingOrderTickets[g_pendingContextCount] = orderTicket;
   g_pendingContextCount++;
   
   Print("Contexto pendiente almacenado - OrderTicket: ", orderTicket);
}
//+------------------------------------------------------------------+
//| Cleanup Stale Pending Contexts                                  |
//+------------------------------------------------------------------+
void CleanupStalePendingContexts()
{
   datetime now = TimeCurrent();
   datetime threshold = now - 300;
   
   for(int i = g_pendingContextCount - 1; i >= 0; i--)
   {
      if(g_pendingContextMap[i].entryTime > 0 && g_pendingContextMap[i].entryTime < threshold)
      {
         Print("Eliminando contexto pendiente obsoleto - OrderTicket: ", g_pendingOrderTickets[i]);
         
         for(int j = i; j < g_pendingContextCount - 1; j++)
         {
            g_pendingContextMap[j] = g_pendingContextMap[j + 1];
            g_pendingOrderTickets[j] = g_pendingOrderTickets[j + 1];
         }
         
         g_pendingContextCount--;
         ArrayResize(g_pendingContextMap, g_pendingContextCount);
         ArrayResize(g_pendingOrderTickets, g_pendingContextCount);
      }
   }
}
//+------------------------------------------------------------------+
//| Check Trade Closures                                             |
//+------------------------------------------------------------------+
void CheckTradeClosures()
{
   ulong currentTickets[];
   int currentCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber || InpMagicNumber == 0)
         {
            ArrayResize(currentTickets, currentCount + 1);
            currentTickets[currentCount] = ticket;
            currentCount++;
         }
      }
   }
   
   for(int i = 0; i < g_lastCheckedCount; i++)
   {
      bool stillOpen = false;
      for(int j = 0; j < currentCount; j++)
      {
         if(g_lastCheckedTickets[i] == currentTickets[j])
         {
            stillOpen = true;
            break;
         }
      }
      
      if(!stillOpen)
      {
         ulong closedTicket = g_lastCheckedTickets[i];
         HistorySelect(TimeCurrent() - 86400, TimeCurrent());
         int deals = HistoryDealsTotal();
         
         for(int d = deals - 1; d >= MathMax(0, deals - 10); d--)
         {
            ulong dealTicket = HistoryDealGetTicket(d);
            if(dealTicket > 0)
            {
               ulong posId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
               ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
               
               if(posId == closedTicket && (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT))
               {
                  string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
                  double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                  double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
                  double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
                  double totalProfit = profit + commission + swap;
                  double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
                  double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
                  double pipValue = g_positionManager.GetPipValue(symbol);
                  double closePips = 0;
                  double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
                  
                  if(pipValue > 0 && volume > 0 && contractSize > 0)
                     closePips = totalProfit / (volume * contractSize * pipValue);
                  
                  bool isWin = (totalProfit > 0);
                  string reason = "";
                  
                  if(closePips >= InpTakeProfitPips * 0.9)
                     reason = "Take Profit alcanzado";
                  else if(closePips <= -InpStopLossPips * 0.9)
                     reason = "Stop Loss alcanzado";
                  else if(closePips > 0)
                     reason = "Cierre manual en ganancia";
                  else
                     reason = "Cierre manual en pérdida";
                  
                  g_telegram.SendTradeClose(closedTicket, closePips, isWin, reason);
                  break;
               }
            }
         }
      }
   }
   
   ArrayResize(g_lastCheckedTickets, currentCount);
   for(int i = 0; i < currentCount; i++)
      g_lastCheckedTickets[i] = currentTickets[i];
   
   g_lastCheckedCount = currentCount;
}
//+------------------------------------------------------------------+
//| Update Professional Dashboard                                    |
//+------------------------------------------------------------------+
void UpdateProfessionalDashboard(void)
{
   // Get performance metrics with fallback values
   double winRate = 0;
   double totalProfit = 0;
   double drawdown = 0;
   double rrRatio = InpRRRatio;
   
   // Try to get real values from position manager
   if(CheckPointer(GetPointer(g_positionManager)) != POINTER_INVALID)
   {
      winRate = g_positionManager.GetWinRate();
      totalProfit = g_positionManager.GetTotalProfit();
      
      // Calculate drawdown from account info
      int totalTrades = g_positionManager.GetTotalTrades();
      if(totalTrades > 0)
      {
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         if(balance > 0)
            drawdown = ((balance - equity) / balance) * 100.0;
      }
   }
   
   g_dashboard.UpdatePerformanceData(winRate, totalProfit, drawdown, rrRatio);
   
   // Get trading status
   int activePositions = g_positionManager.CountPositions();
   int maxPositions = InpMaxPositions;
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   g_dashboard.UpdateTradingData(activePositions, maxPositions, accountEquity, accountBalance);
   
   // Get statistics with safe fallbacks
   int totalTrades = 0;
   int winTrades = 0;
   double avgProfit = 0;
   double avgLoss = 0;
   
   if(CheckPointer(GetPointer(g_positionManager)) != POINTER_INVALID)
   {
      totalTrades = g_positionManager.GetTotalTrades();
      winTrades = (int)(totalTrades * (winRate / 100.0));
      
      // Calculate average profit/loss from history
      HistorySelect(0, TimeCurrent());
      int deals = HistoryDealsTotal();
      double totalProfitSum = 0;
      double totalLossSum = 0;
      int profitCount = 0;
      int lossCount = 0;
      
      for(int i = 0; i < deals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
         {
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber)
            {
               double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
               if(profit > 0)
               {
                  totalProfitSum += profit;
                  profitCount++;
               }
               else if(profit < 0)
               {
                  totalLossSum += profit;
                  lossCount++;
               }
            }
         }
      }
      
      if(profitCount > 0) avgProfit = totalProfitSum / profitCount;
      if(lossCount > 0) avgLoss = totalLossSum / lossCount;
   }
   
   g_dashboard.UpdateStatisticsData(avgProfit, avgLoss, totalTrades, winTrades);
}
//+------------------------------------------------------------------+
//| Chart Event Handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
   if(InpMultiPairMode)
   {
      if(g_scanner.HandleChartEvent(id, lparam, dparam, sparam))
      {
         return;
      }
   }
   
   if(id == CHARTEVENT_KEYDOWN)
   {
      if(lparam == 'R' || lparam == 'r')
      {
         Print("Forzando escaneo manual...");
         if(InpMultiPairMode)
         {
            g_scanner.ScanAll();
            PrintScanResults();
         }
         else
         {
            AnalyzeAndTradeSingle();
         }
      }
      else if(lparam == 'P' || lparam == 'p')
      {
//          if(InpMultiPairMode)
//          {
//             static bool panelVisible = true;
//             if(panelVisible)
//                g_scanner.DeletePanel();
//             else
//                g_scanner.CreatePanel();
//             panelVisible = !panelVisible;
//          }
      }
      else if(lparam == 'C' || lparam == 'c')
      {
         g_openedChartsCount = 0;
         ArrayResize(g_openedCharts, 0);
         Print("Lista de gráficos abiertos reiniciada");
      }
      else if(lparam == 'T' || lparam == 't')
      {
         if(InpMultiPairMode)
         {
            Print("Iniciando entrenamiento desde teclado...");
            g_scanner.StartTraining();
         }
      }
      else if(lparam == 'L' || lparam == 'l')
      {
         if(InpAdaptiveLearning)
         {
            Print("Exportando datos de aprendizaje...");
            g_adaptiveLearning.ExportLearningData();
            Print("Estadísticas: Trades=", g_adaptiveLearning.GetHistoryCount(),
               " Patrones=", g_adaptiveLearning.GetPatternCount());
         }
      }
      else if(lparam == 'S' || lparam == 's')
      {
         if(InpAdaptiveLearning)
         {
            Print("=== ESTADÍSTICAS DE APRENDIZAJE ADAPTATIVO ===");
            Print("Historial: ", g_adaptiveLearning.GetHistoryCount());
            Print("Patrones: ", g_adaptiveLearning.GetPatternCount());
            Print("Win Rate: ", DoubleToString(g_adaptiveLearning.GetOverallWinRate(), 1), "%");
         }
      }
   }
}
//+------------------------------------------------------------------+
//| Trade Transaction Handler                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(!InpAdaptiveLearning)
      return;
   
   // Handle trade transactions for adaptive learning
   // Implementation depends on adaptive learning module
}
//+------------------------------------------------------------------+
//| Tester Function                                                  |
//+------------------------------------------------------------------+
double OnTester()
{
   double winRate = g_positionManager.GetWinRate();
   double profit = g_positionManager.GetTotalProfit();
   int trades = g_positionManager.GetTotalTrades();
   
   if(trades < 10) return 0;
   
   double profitFactor = profit > 0 ? profit / MathMax(1, trades) : 0;
   double score = (winRate * 0.4) + (profitFactor * 0.6);
   
   return score;
}


bool ParseArbTriangle(string tri,string &a,string &b,string &c)
{
   string parts[];
   int n=StringSplit(tri, ',', parts);
   if(n<3) return false;
   a=parts[0]; b=parts[1]; c=parts[2];
   StringTrimLeft(a); StringTrimRight(a);
   StringTrimLeft(b); StringTrimRight(b);
   StringTrimLeft(c); StringTrimRight(c);
   return (StringLen(a)>0 && StringLen(b)>0 && StringLen(c)>0);
}

bool InitArbitrageStrategy()
{
   if(!InpEnableArbitrageStrategy) return true;
   if(!ParseArbTriangle(InpArbTriangle,g_arbSymA,g_arbSymB,g_arbSymC))
   {
      Print("ArbStrategy: invalid triangle config: ", InpArbTriangle);
      return false;
   }
   Print("ArbStrategy initialized: ", g_arbSymA, " + ", g_arbSymB, " + ", g_arbSymC);
   return true;
}

bool SendArbOrder(string symbol, ENUM_ORDER_TYPE orderType, double lot, string comment)
{
   MqlTick tk;
   if(!SymbolInfoTick(symbol, tk)) return false;

   MqlTradeRequest req; MqlTradeResult res;
   ZeroMemory(req); ZeroMemory(res);
   req.action = TRADE_ACTION_DEAL;
   req.symbol = symbol;
   req.volume = lot;
   req.magic = InpArbMagicNumber;
   req.deviation = 20;
   req.comment = comment;
   req.type = orderType;
   req.price = (orderType==ORDER_TYPE_BUY)?tk.ask:tk.bid;
   req.type_filling = ORDER_FILLING_FOK;

   if(!OrderSend(req,res)) return false;
   if(res.retcode!=TRADE_RETCODE_DONE && res.retcode!=TRADE_RETCODE_PLACED)
   {
      Print("Arb order failed ", symbol, " rc=", res.retcode);
      return false;
   }
   return true;
}

bool HasArbPositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)==InpArbMagicNumber) return true;
   }
   return false;
}

double GetArbBasketProfit()
{
   double pl=0.0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpArbMagicNumber) continue;
      pl += PositionGetDouble(POSITION_PROFIT);
   }
   return pl;
}

void CloseArbBasket(string reason)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpArbMagicNumber) continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      double vol=PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE pt=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      MqlTick tick; if(!SymbolInfoTick(symbol,tick)) continue;
      MqlTradeRequest req; MqlTradeResult res;
      ZeroMemory(req); ZeroMemory(res);
      req.action=TRADE_ACTION_DEAL;
      req.symbol=symbol;
      req.volume=vol;
      req.magic=InpArbMagicNumber;
      req.deviation=20;
      req.type=(pt==POSITION_TYPE_BUY)?ORDER_TYPE_SELL:ORDER_TYPE_BUY;
      req.price=(req.type==ORDER_TYPE_BUY)?tick.ask:tick.bid;
      req.type_filling=ORDER_FILLING_FOK;
      req.comment="ArbClose "+reason;
      OrderSend(req,res);
   }
   g_arbBasketOpen=false;
   g_arbDirection=0;
}

void ProcessArbitrageStrategy()
{
   if(!InpEnableArbitrageStrategy) return;
   if(g_arbSymA=="" || g_arbSymB=="" || g_arbSymC=="") return;

   bool has=HasArbPositions();
   if(has && !g_arbBasketOpen) g_arbBasketOpen=true;

   if(g_arbBasketOpen)
   {
      double pl=GetArbBasketProfit();
      if(pl>=InpArbTakeProfit) { CloseArbBasket("TP"); return; }
      if(pl<=-InpArbStopLoss) { CloseArbBasket("SL"); return; }
      if((TimeCurrent()-g_arbOpenTime) > InpArbMaxHoldSeconds) { CloseArbBasket("Timeout"); return; }
      return;
   }

   MqlTick a,b,c;
   if(!SymbolInfoTick(g_arbSymA,a) || !SymbolInfoTick(g_arbSymB,b) || !SymbolInfoTick(g_arbSymC,c)) return;
   if(a.ask<=0 || b.ask<=0 || c.ask<=0) return;

   double edgeBuy = (b.bid*c.bid - a.ask);
   double edgeSell = (a.bid - b.ask*c.ask);
   double pointA = SymbolInfoDouble(g_arbSymA,SYMBOL_POINT);
   if(pointA<=0) return;
   double edgePipsBuy = edgeBuy/pointA;
   double edgePipsSell = edgeSell/pointA;

   NNPrediction pred = g_neuralNet.Predict();
   bool nnBuy = (!InpUseNeuralNetwork || pred.buyProb>=0.55);
   bool nnSell = (!InpUseNeuralNetwork || pred.sellProb>=0.55);

   if(edgePipsBuy>=InpArbMinEdgePips && nnBuy)
   {
      double lot3=NormalizeDouble(b.ask*InpArbBaseLot,2);
      if(SendArbOrder(g_arbSymA,ORDER_TYPE_BUY,InpArbBaseLot,"ArbA Buy") &&
         SendArbOrder(g_arbSymB,ORDER_TYPE_SELL,InpArbBaseLot,"ArbB Sell") &&
         SendArbOrder(g_arbSymC,ORDER_TYPE_SELL,lot3,"ArbC Sell"))
      {
         g_arbBasketOpen=true;
         g_arbDirection=1;
         g_arbOpenTime=TimeCurrent();
      }
      else CloseArbBasket("PartialOpen");
   }
   else if(edgePipsSell>=InpArbMinEdgePips && nnSell)
   {
      double lot3=NormalizeDouble(b.ask*InpArbBaseLot,2);
      if(SendArbOrder(g_arbSymA,ORDER_TYPE_SELL,InpArbBaseLot,"ArbA Sell") &&
         SendArbOrder(g_arbSymB,ORDER_TYPE_BUY,InpArbBaseLot,"ArbB Buy") &&
         SendArbOrder(g_arbSymC,ORDER_TYPE_BUY,lot3,"ArbC Buy"))
      {
         g_arbBasketOpen=true;
         g_arbDirection=-1;
         g_arbOpenTime=TimeCurrent();
      }
      else CloseArbBasket("PartialOpen");
   }
}

//+------------------------------------------------------------------+
//| END OF FOREXBOTPRO v7.1                                         |
//+------------------------------------------------------------------+
