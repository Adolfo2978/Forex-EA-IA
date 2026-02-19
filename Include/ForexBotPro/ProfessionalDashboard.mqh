//+------------------------------------------------------------------+
//|                                         ProfessionalDashboard.mqh|
//|               Enhanced Visual Template - Real-Time Statistics    |
//|                   Professional Grade MT5 Dashboard               |
//|                                                                  |
//| Features:                                                        |
//| + FULLY RESPONSIVE - Adapts to any screen/chart size            |
//| + Dynamic layout with proportional scaling                      |
//| + Real-time data updates every tick                             |
//| + Professional color scheme with high contrast                  |
//| + Live metrics: Win Rate, Profit, Drawdown, Risk/Reward        |
//| + Automatic chart resize detection                              |
//| + Optimized typography scaling for readability                  |
//| + CORRECTED POSITIONING & SIZING (Critical Fixes Applied)       |
//+------------------------------------------------------------------+

#property copyright "© 2024-2026 ForexBotPro Inc."
#property version   "3.2"  // Updated version with critical fixes
#property description "Professional Dashboard - Fully Responsive Design (FIXED)"

#include <Object.mqh>


//+------------------------------------------------------------------+
//| Enumerations for color themes                                   |
//+------------------------------------------------------------------+

enum ENUM_DASHBOARD_THEME
{
   THEME_DARK_PROFESSIONAL = 0,    // Professional dark theme (default)
   THEME_LIGHT_MODERN = 1,          // Light modern theme
   THEME_CYBERPUNK = 2,             // Cyberpunk neon theme
   THEME_MINIMALIST = 3             // Clean minimalist theme
};

//+------------------------------------------------------------------+
//| Color Definitions                                               |
//+------------------------------------------------------------------+

struct DashboardColors
{
   color colorBackground;
   color colorBorder;
   color colorHeader;
   color colorHeaderText;
   color colorPositive;      // Profit/Win
   color colorNegative;      // Loss/Bad
   color colorNeutral;       // Neutral data
   color colorWarning;       // Warning/Caution
   color colorText;
   color colorTextSecondary;
   color colorHighlight;
   color colorAlertBuy;
   color colorAlertSell;
};

//+------------------------------------------------------------------+
//| Professional Dashboard Class - FULLY RESPONSIVE (FIXED)         |
//+------------------------------------------------------------------+

class CProfessionalDashboard : public CObject
{
private:
   string            m_panelName;
   long              m_chartId;
   int               m_subWindow;   // Subwindow index (always 0 for main chart)
   int               m_x;
   int               m_y;
   int               m_width;
   int               m_height;
   int               m_originalX;   // Original X value (negative = from right)
   int               m_originalY;   // Original Y value
   bool              m_rightAligned;
   bool              m_fullWidthMode;   // Full width responsive mode
   
   // Theme and colors
   ENUM_DASHBOARD_THEME m_theme;
   DashboardColors   m_colors;
   
   // Layout proportions (responsive)
   double            m_headerHeightRatio;
   double            m_sectionHeightRatio;
   double            m_cardPaddingRatio;
   double            m_cardGapRatio;
   
   // Data refresh
   datetime          m_lastUpdate;
   int               m_updateInterval;
   datetime          m_lastChartResizeCheck;
   long              m_lastChartWidth;
   long              m_lastChartHeight;
   
   // Visual elements
   bool              m_showPerformance;
   bool              m_showTrading;
   bool              m_showStatistics;
   
   // Font scaling
   int               m_baseFontSize;
   double            m_fontScaleFactor;
   
public:
   CProfessionalDashboard(void);
   ~CProfessionalDashboard(void);
   
   // Initialization (CORRECTED SIGNATURE - theme as 4th param)
   bool              Initialize(long chartId, 
                                int x = -1, 
                                int y = 10, 
                                ENUM_DASHBOARD_THEME theme = THEME_DARK_PROFESSIONAL,
                                bool fullWidthMode = false);
   
   // Configuration
   void              SetPosition(int x, int y);
   void              SetSize(int width, int height);
   void              SetTheme(ENUM_DASHBOARD_THEME theme);
   void              SetPanelName(string panelName);
   void              SetSections(bool performance, bool trading, bool statistics);
   void              SetUpdateInterval(int milliseconds);
   void              SetFullWidthMode(bool enable);
   
   // Updates
   void              UpdatePerformanceData(double winRate, double totalProfit, double drawdown, double rrRatio);
   void              UpdateTradingData(int activePositions, int maxPositions, double equity, double balance);
   void              UpdateStatisticsData(double avgProfit, double avgLoss, int totalTrades, int winTrades);
   
   // Drawing
   void              Draw(void);
   bool              NeedsUpdate(void);
   void              RecalculateLayout(void);
   void              RecalculatePosition(void);
   bool              CheckChartResize(void);
   
   // Cleanup
   void              Cleanup(void);
   
private:
   // Helper methods
   void              InitializeColors(void);
   void              DrawHeader(void);
   void              DrawPerformanceSection(int startY);
   void              DrawTradingSection(int startY);
   void              DrawStatisticsSection(int startY);
   void              DrawLabel(int x, int y, string text, color clr, string fontName = "Arial Bold", int fontSize = 11);
   void              DrawBox(int x, int y, int width, int height, color borderColor, color bgColor, int borderWidth = 2);
   void              DrawHorizontalLine(int x, int y, int width, color clr);
   int               ScaledFontSize(int baseSize);
   int               ScaledValue(int baseValue);
   string            GenerateObjectName(string baseName, int x, int y);
   
   // Data storage
   double            m_winRate;
   double            m_totalProfit;
   double            m_drawdown;
   double            m_rrRatio;
   
   int               m_activePositions;
   int               m_maxPositions;
   double            m_equity;
   double            m_balance;
   
   double            m_avgProfit;
   double            m_avgLoss;
   int               m_totalTrades;
   int               m_winTrades;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+

CProfessionalDashboard::CProfessionalDashboard(void)
   : m_panelName("FOREXBOTPRO_DASHBOARD"),
     m_chartId(0),
     m_subWindow(0),
     m_x(10),
     m_y(10),
     m_width(300),
     m_height(520),
     m_originalX(-520),  // Default: 520px from right edge
     m_originalY(30),
     m_rightAligned(true),
     m_fullWidthMode(true),  // Default: OFF (use manual sizing)
     m_theme(THEME_DARK_PROFESSIONAL),
    m_headerHeightRatio(0.12),
    m_sectionHeightRatio(0.23),
    m_cardPaddingRatio(0.015),
    m_cardGapRatio(0.015),
     m_lastUpdate(0),
     m_updateInterval(500),
     m_lastChartResizeCheck(0),
     m_lastChartWidth(0),
     m_lastChartHeight(0),
     m_showPerformance(true),
     m_showTrading(true),
     m_showStatistics(true),
     m_baseFontSize(10),
     m_fontScaleFactor(1.0),
     m_winRate(0),
     m_totalProfit(0),
     m_drawdown(0),
     m_rrRatio(0),
     m_activePositions(0),
     m_maxPositions(0),
     m_equity(0),
     m_balance(0),
     m_avgProfit(0),
     m_avgLoss(0),
     m_totalTrades(0),
     m_winTrades(0)
{
   InitializeColors();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+

CProfessionalDashboard::~CProfessionalDashboard(void)
{
   Cleanup();
}

//+------------------------------------------------------------------+
//| Initialize Dashboard - CORRECTED SIGNATURE                      |
//+------------------------------------------------------------------+
// ✅ FIX: 4th parameter = theme (ENUM), 5th parameter = fullWidthMode (bool)
// Matches EA call: g_dashboard.Initialize(ChartID(), x, y, theme);
bool CProfessionalDashboard::Initialize(long chartId, 
                                        int x = -1, 
                                        int y = 10, 
                                        ENUM_DASHBOARD_THEME theme = THEME_DARK_PROFESSIONAL,
                                        bool fullWidthMode = false)
{
   m_chartId = chartId;
   m_subWindow = 0; // Always use main chart window
   m_x = x;
   m_y = y;
   m_originalX = x;
   m_originalY = y;
   m_rightAligned = (x < 0);
   m_fullWidthMode = fullWidthMode;
   m_theme = theme;
   
   InitializeColors();
   RecalculateLayout();
   m_lastUpdate = 0;
   
   // Save initial chart dimensions for resize detection
   m_lastChartWidth = ChartGetInteger(m_chartId, CHART_WIDTH_IN_PIXELS);
   m_lastChartHeight = ChartGetInteger(m_chartId, CHART_HEIGHT_IN_PIXELS);
   
   PrintFormat("[Dashboard] Inicializado | Chart: %d | Pos: x=%d y=%d | Tema: %d | Modo: %s",
               m_chartId, x, y, theme, fullWidthMode ? "FULL_WIDTH" : "MANUAL");
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialize Color Scheme                                         |
//+------------------------------------------------------------------+

void CProfessionalDashboard::InitializeColors(void)
{
   switch(m_theme)
   {
      case THEME_DARK_PROFESSIONAL:
         m_colors.colorBackground = C'18,22,28';
         m_colors.colorBorder = C'65,105,225';
         m_colors.colorHeader = C'25,42,86';
         m_colors.colorHeaderText = C'255,255,255';
         m_colors.colorPositive = C'0,220,140';
         m_colors.colorNegative = C'255,75,75';
         m_colors.colorNeutral = C'180,190,200';
         m_colors.colorWarning = C'255,200,50';
         m_colors.colorText = C'240,245,255';
         m_colors.colorTextSecondary = C'150,170,190';
         m_colors.colorHighlight = C'90,150,255';
         m_colors.colorAlertBuy = C'0,210,120';
         m_colors.colorAlertSell = C'255,60,60';
         break;
         
      case THEME_LIGHT_MODERN:
         m_colors.colorBackground = C'248,249,252';
         m_colors.colorBorder = C'80,100,130';
         m_colors.colorHeader = C'60,90,130';
         m_colors.colorHeaderText = C'255,255,255';
         m_colors.colorPositive = C'40,160,80';
         m_colors.colorNegative = C'230,50,70';
         m_colors.colorNeutral = C'110,110,110';
         m_colors.colorWarning = C'240,150,30';
         m_colors.colorText = C'35,40,45';
         m_colors.colorTextSecondary = C'100,100,100';
         m_colors.colorHighlight = C'70,120,200';
         m_colors.colorAlertBuy = C'0,170,90';
         m_colors.colorAlertSell = C'230,60,60';
         break;
         
      case THEME_CYBERPUNK:
         m_colors.colorBackground = C'8,5,18';
         m_colors.colorBorder = C'200,50,255';
         m_colors.colorHeader = C'60,10,80';
         m_colors.colorHeaderText = C'0,240,255';
         m_colors.colorPositive = C'0,240,200';
         m_colors.colorNegative = C'255,50,200';
         m_colors.colorNeutral = C'150,100,255';
         m_colors.colorWarning = C'255,220,50';
         m_colors.colorText = C'180,220,255';
         m_colors.colorTextSecondary = C'120,150,220';
         m_colors.colorHighlight = C'180,80,255';
         m_colors.colorAlertBuy = C'0,255,220';
         m_colors.colorAlertSell = C'255,80,220';
         break;
         
      case THEME_MINIMALIST:
         m_colors.colorBackground = C'252,253,255';
         m_colors.colorBorder = C'210,215,225';
         m_colors.colorHeader = C'90,100,115';
         m_colors.colorHeaderText = C'255,255,255';
         m_colors.colorPositive = C'46,180,80';
         m_colors.colorNegative = C'235,60,75';
         m_colors.colorNeutral = C'140,145,155';
         m_colors.colorWarning = C'245,150,40';
         m_colors.colorText = C'45,50,60';
         m_colors.colorTextSecondary = C'115,120,135';
         m_colors.colorHighlight = C'80,140,220';
         m_colors.colorAlertBuy = C'0,190,100';
         m_colors.colorAlertSell = C'240,65,65';
         break;
   }
}

//+------------------------------------------------------------------+
//| Set Position                                                     |
//+------------------------------------------------------------------+

void CProfessionalDashboard::SetPosition(int x, int y)
{
   m_x = x;
   m_y = y;
   m_originalX = x;
   m_originalY = y;
   m_rightAligned = (x < 0);
   m_lastUpdate = 0;
}

//+------------------------------------------------------------------+
//| Set Size                                                         |
//+------------------------------------------------------------------+

void CProfessionalDashboard::SetSize(int width, int height)
{
   // Only apply manual size if NOT in full-width mode
   if(!m_fullWidthMode)
   {
      m_width = MathMax(width, 300);   // Enforce minimum width
      m_height = MathMax(height, 520); // Enforce minimum height
   }
   m_lastUpdate = 0;
}

//+------------------------------------------------------------------+
//| Set Full Width Mode                                              |
//+------------------------------------------------------------------+

void CProfessionalDashboard::SetFullWidthMode(bool enable)
{
   m_fullWidthMode = enable;
   RecalculateLayout();  // Recalculate immediately
   m_lastUpdate = 0;
}

//+------------------------------------------------------------------+
//| Set Theme                                                        |
//+------------------------------------------------------------------+

void CProfessionalDashboard::SetTheme(ENUM_DASHBOARD_THEME theme)
{
   m_theme = theme;
   InitializeColors();
   m_lastUpdate = 0;
}

//+------------------------------------------------------------------+
//| Set Panel Name (unique object namespace)                        |
//+------------------------------------------------------------------+

void CProfessionalDashboard::SetPanelName(string panelName)
{
   if(StringLen(panelName) < 3)
      return;

   Cleanup();
   m_panelName = panelName;
   m_lastUpdate = 0;
}

//+------------------------------------------------------------------+
//| Set Sections                                                     |
//+------------------------------------------------------------------+

void CProfessionalDashboard::SetSections(bool performance, bool trading, bool statistics)
{
   m_showPerformance = performance;
   m_showTrading = trading;
   m_showStatistics = statistics;
   RecalculateLayout();  // Recalculate height based on visible sections
   m_lastUpdate = 0;
}

//+------------------------------------------------------------------+
//| Set Update Interval                                              |
//+------------------------------------------------------------------+

void CProfessionalDashboard::SetUpdateInterval(int milliseconds)
{
   m_updateInterval = MathMax(milliseconds, 100); // Minimum 100ms
}

//+------------------------------------------------------------------+
//| Update Performance Data                                          |
//+------------------------------------------------------------------+

void CProfessionalDashboard::UpdatePerformanceData(double winRate, double totalProfit, double drawdown, double rrRatio)
{
   m_winRate = winRate;
   m_totalProfit = totalProfit;
   m_drawdown = drawdown;
   m_rrRatio = rrRatio;
}

//+------------------------------------------------------------------+
//| Update Trading Data                                              |
//+------------------------------------------------------------------+

void CProfessionalDashboard::UpdateTradingData(int activePositions, int maxPositions, double equity, double balance)
{
   m_activePositions = activePositions;
   m_maxPositions = maxPositions;
   m_equity = equity;
   m_balance = balance;
}

//+------------------------------------------------------------------+
//| Update Statistics Data                                           |
//+------------------------------------------------------------------+

void CProfessionalDashboard::UpdateStatisticsData(double avgProfit, double avgLoss, int totalTrades, int winTrades)
{
   m_avgProfit = avgProfit;
   m_avgLoss = avgLoss;
   m_totalTrades = totalTrades;
   m_winTrades = winTrades;
}

//+------------------------------------------------------------------+
//| Check if Update Needed                                           |
//+------------------------------------------------------------------+

bool CProfessionalDashboard::NeedsUpdate(void)
{
   datetime currentTime = TimeCurrent();
   return ((currentTime - m_lastUpdate) * 1000 >= m_updateInterval || m_lastUpdate == 0);
}

//+------------------------------------------------------------------+
//| Check Chart Resize (detect screen changes)                      |
//+------------------------------------------------------------------+

bool CProfessionalDashboard::CheckChartResize(void)
{
   datetime now = TimeCurrent();
   if((now - m_lastChartResizeCheck) * 1000 < 200)  // Check every 200ms
      return false;
      
   m_lastChartResizeCheck = now;
   
   long currentWidth = ChartGetInteger(m_chartId, CHART_WIDTH_IN_PIXELS);
   long currentHeight = ChartGetInteger(m_chartId, CHART_HEIGHT_IN_PIXELS);
   
   if(currentWidth != m_lastChartWidth || currentHeight != m_lastChartHeight)
   {
      m_lastChartWidth = currentWidth;
      m_lastChartHeight = currentHeight;
      RecalculateLayout();
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Recalculate Layout - FULLY RESPONSIVE CORE (FIXED)              |
//+------------------------------------------------------------------+

void CProfessionalDashboard::RecalculateLayout(void)
{
   if(m_chartId == 0) return;
   
   long chartWidth = ChartGetInteger(m_chartId, CHART_WIDTH_IN_PIXELS);
   long chartHeight = ChartGetInteger(m_chartId, CHART_HEIGHT_IN_PIXELS);
   
   // Safety margins (20px minimum)
   const int MIN_MARGIN = 20;
   
   // ===== FIX #1: CORRECT RIGHT-ALIGNED POSITIONING =====
   if(m_rightAligned)
   {
      // m_originalX is negative (e.g., -520 = 520px from right edge)
      m_x = (int)chartWidth + m_originalX - MIN_MARGIN;
      
      // Ensure panel stays within visible area
      if(m_x < MIN_MARGIN) m_x = MIN_MARGIN;
      if(m_x > chartWidth - MIN_MARGIN) m_x = (int)chartWidth - MIN_MARGIN - m_width;
   }
   else
   {
      // Left-aligned: respect original X with margin
      m_x = MathMax(m_originalX, MIN_MARGIN);
      if(m_x > chartWidth - MIN_MARGIN - m_width)
         m_x = (int)chartWidth - MIN_MARGIN - m_width;
   }
   
   // ===== FIX #2: CORRECT Y POSITIONING =====
   m_y = MathMax(m_originalY, MIN_MARGIN);
   if(m_y > chartHeight - MIN_MARGIN - m_height)
      m_y = (int)chartHeight - MIN_MARGIN - m_height;
   
   // ===== FIX #3: SIZE HANDLING =====
   if(m_fullWidthMode)
   {
      // Full width mode: use 96% of chart width
      m_width = (int)(chartWidth * 0.96);
      m_x = MIN_MARGIN; // Always left-aligned in full-width mode
   }
   else
   {
      // Manual mode: respect SetSize() values but enforce minimums
      m_width = MathMax(m_width, 380);
      m_height = MathMax(m_height, 300);
      
      // Ensure panel fits on screen
      if(m_x + m_width > chartWidth - MIN_MARGIN)
         m_x = (int)chartWidth - MIN_MARGIN - m_width;
      if(m_y + m_height > chartHeight - MIN_MARGIN)
         m_y = (int)chartHeight - MIN_MARGIN - m_height;
   }
   
   // ===== FIX #4: HEIGHT BASED ON VISIBLE SECTIONS =====
   int visibleSections = 0;
   if(m_showPerformance) visibleSections++;
   if(m_showTrading) visibleSections++;
   if(m_showStatistics) visibleSections++;
   
   if(visibleSections == 0) visibleSections = 1; // At least one section
   
   // Calculate height: header + sections + spacing
   double contentRatio = visibleSections * m_sectionHeightRatio;
   double totalRatio = m_headerHeightRatio + contentRatio + 0.02; // +4% for spacing
   
   if(m_fullWidthMode)
   {
      // In full-width mode, use proportional height
      if(totalRatio > 0.90) totalRatio = 0.90; // Max 90% of chart height
      m_height = (int)(chartHeight * totalRatio);
   }
   else
   {
      // In manual mode, keep user-defined height but ensure minimum
      m_height = MathMax(m_height, 300);
   }
   
   // ===== FIX #5: FONT SCALING =====
   double widthScale = (double)m_width / 420.0;   // Base design width
   double heightScale = (double)m_height / 480.0; // Base design height
   m_fontScaleFactor = MathMin(widthScale, heightScale);
   m_fontScaleFactor = MathMax(m_fontScaleFactor, 0.8);  // Min scale
   m_fontScaleFactor = MathMin(m_fontScaleFactor, 1.5);  // Max scale
   
   // Debug output for positioning issues (only on first draw)
   static bool firstDraw = true;
   if(firstDraw)
   {
      PrintFormat("[Dashboard Layout] Chart: %dx%d | Panel: x=%d y=%d w=%d h=%d | Mode: %s",
                  chartWidth, chartHeight, m_x, m_y, m_width, m_height,
                  m_fullWidthMode ? "FULL_WIDTH" : "MANUAL");
      firstDraw = false;
   }
   
   m_lastUpdate = 0; // Force redraw
}

//+------------------------------------------------------------------+
//| Recalculate Position (BACKWARD COMPATIBILITY)                   |
//+------------------------------------------------------------------+

void CProfessionalDashboard::RecalculatePosition(void)
{
   RecalculateLayout();
}

//+------------------------------------------------------------------+
//| Scaled Font Size (responsive typography)                        |
//+------------------------------------------------------------------+

int CProfessionalDashboard::ScaledFontSize(int baseSize)
{
   int scaled = (int)(baseSize * m_fontScaleFactor);
   return MathMin(MathMax(scaled, 8), 24); // 8-24px range
}

//+------------------------------------------------------------------+
//| Scaled Value (for spacing, padding, etc.)                       |
//+------------------------------------------------------------------+

int CProfessionalDashboard::ScaledValue(int baseValue)
{
   int scaled = (int)(baseValue * m_fontScaleFactor);
   return MathMax(scaled, 2);
}

//+------------------------------------------------------------------+
//| Generate Unique Object Name                                     |
//+------------------------------------------------------------------+

string CProfessionalDashboard::GenerateObjectName(string baseName, int x, int y)
{
   // Include chart ID to avoid conflicts across charts
   return StringFormat("%s_%d_%s_%d_%d", 
                       m_panelName, 
                       m_chartId, 
                       baseName, 
                       x, 
                       y);
}

//+------------------------------------------------------------------+
//| Draw Dashboard - FULLY RESPONSIVE                               |
//+------------------------------------------------------------------+

void CProfessionalDashboard::Draw(void)
{
   // Skip if chart ID is invalid
   if(m_chartId == 0) return;
   
   // Detect chart resize
   CheckChartResize();
   
   if(!NeedsUpdate())
      return;
      
   Cleanup();
   
   // Draw main background box
   DrawBox(m_x, m_y, m_width, m_height, m_colors.colorBorder, m_colors.colorBackground, 2);
   
   // Draw sections dynamically
   int currentY = m_y + ScaledValue(15);
   int sectionHeight = (int)(m_height * m_sectionHeightRatio);
   int spacing = ScaledValue(8);
   
   // Header section
   DrawHeader();
   currentY += (int)(m_height * m_headerHeightRatio) + spacing;
   
   // Performance section
   if(m_showPerformance)
   {
      DrawPerformanceSection(currentY);
      currentY += sectionHeight + spacing;
   }
   
   // Trading section
   if(m_showTrading)
   {
      DrawTradingSection(currentY);
      currentY += sectionHeight + spacing;
   }
   
   // Statistics section
   if(m_showStatistics)
   {
      DrawStatisticsSection(currentY);
   }
   
   m_lastUpdate = TimeCurrent();
   ChartRedraw(m_chartId);
}

//+------------------------------------------------------------------+
//| Draw Header - RESPONSIVE                                        |
//+------------------------------------------------------------------+

void CProfessionalDashboard::DrawHeader(void)
{
   int headerHeight = (int)(m_height * m_headerHeightRatio);
   int hX = m_x + ScaledValue(15);
   int hY = m_y + ScaledValue(8);
   int headerWidth = m_width - ScaledValue(30);
   
   // Header background
   DrawBox(hX, hY, headerWidth, headerHeight - ScaledValue(12), m_colors.colorBorder, m_colors.colorHeader, 2);
   
   // Main title
   DrawLabel(hX + ScaledValue(12), hY + ScaledValue(6), 
            "FOREXBOTPRO v7.1", 
            m_colors.colorHeaderText, 
            "Arial Black", 
            ScaledFontSize(13));
   
   // Subtitle
   DrawLabel(hX + ScaledValue(12), hY + ScaledValue(26), 
            "Professional Trading Dashboard", 
            m_colors.colorTextSecondary, 
            "Arial", 
            ScaledFontSize(11));
   
   // Status indicator (right-aligned)
   string statusText = "● AWAITING SIGNAL";
   color statusColor = m_colors.colorWarning;
   if(m_activePositions > 0)
   {
      statusText = "● TRADING ACTIVE";
      statusColor = m_colors.colorPositive;
   }
   
   DrawLabel(hX + headerWidth - ScaledValue(150), hY + ScaledValue(6), 
            statusText, 
            statusColor, 
            "Arial Bold", 
            ScaledFontSize(10));
}

//+------------------------------------------------------------------+
//| Draw Performance Section - RESPONSIVE GRID                      |
//+------------------------------------------------------------------+

void CProfessionalDashboard::DrawPerformanceSection(int startY)
{
   int sX = m_x + ScaledValue(14);
   int sY = startY;
   int sectionWidth = m_width - ScaledValue(26);
   
   // Section title
   DrawLabel(sX, sY, "PERFORMANCE METRICS", m_colors.colorHighlight, "Arial Black", ScaledFontSize(12));
   DrawHorizontalLine(sX, sY + ScaledValue(18), sectionWidth, m_colors.colorBorder);
   
   sY += ScaledValue(24);
   
   // Responsive 2x2 grid
   int cardPadding = (int)(sectionWidth * m_cardPaddingRatio);
   int cardGap = (int)(sectionWidth * m_cardGapRatio);
   int cardWidth = (sectionWidth - cardPadding * 2 - cardGap) / 2;
   int cardHeight = (int)((m_height * m_sectionHeightRatio) * 0.42);
   
   // Card 1: Win Rate
   DrawBox(sX + cardPadding, sY, cardWidth, cardHeight, m_colors.colorBorder, C'30,38,48', 2);
   DrawLabel(sX + cardPadding + ScaledValue(10), sY + ScaledValue(6), 
            "Win Rate", m_colors.colorTextSecondary, "Arial", ScaledFontSize(10));
   color winColor = m_winRate >= 50 ? m_colors.colorPositive : m_colors.colorNegative;
   DrawLabel(sX + cardPadding + ScaledValue(10), sY + ScaledValue(20), 
            DoubleToString(m_winRate, 1) + "%", winColor, "Arial Black", ScaledFontSize(14));
   
   // Card 2: Total Profit
   DrawBox(sX + cardPadding + cardWidth + cardGap, sY, cardWidth, cardHeight, m_colors.colorBorder, C'30,38,48', 2);
   DrawLabel(sX + cardPadding + cardWidth + cardGap + ScaledValue(12), sY + ScaledValue(6), 
            "Total Profit", m_colors.colorTextSecondary, "Arial", ScaledFontSize(10));
   color profitColor = m_totalProfit >= 0 ? m_colors.colorPositive : m_colors.colorNegative;
   DrawLabel(sX + cardPadding + cardWidth + cardGap + ScaledValue(12), sY + ScaledValue(20), 
            DoubleToString(m_totalProfit, 2), profitColor, "Arial Black", ScaledFontSize(14));
   
   sY += cardHeight + ScaledValue(8);
   
   // Card 3: Drawdown
   DrawBox(sX + cardPadding, sY, cardWidth, cardHeight, m_colors.colorBorder, C'30,38,48', 2);
   DrawLabel(sX + cardPadding + ScaledValue(10), sY + ScaledValue(6), 
            "Drawdown", m_colors.colorTextSecondary, "Arial", ScaledFontSize(10));
   DrawLabel(sX + cardPadding + ScaledValue(10), sY + ScaledValue(20), 
            DoubleToString(m_drawdown, 2) + "%", m_colors.colorWarning, "Arial Black", ScaledFontSize(14));
   
   // Card 4: Risk/Reward
   DrawBox(sX + cardPadding + cardWidth + cardGap, sY, cardWidth, cardHeight, m_colors.colorBorder, C'30,38,48', 2);
   DrawLabel(sX + cardPadding + cardWidth + cardGap + ScaledValue(10), sY + ScaledValue(6), 
            "Risk/Reward", m_colors.colorTextSecondary, "Arial", ScaledFontSize(10));
   DrawLabel(sX + cardPadding + cardWidth + cardGap + ScaledValue(10), sY + ScaledValue(20), 
            "1:" + DoubleToString(m_rrRatio, 1), m_colors.colorHighlight, "Arial Black", ScaledFontSize(14));
}

//+------------------------------------------------------------------+
//| Draw Trading Section - RESPONSIVE                               |
//+------------------------------------------------------------------+

void CProfessionalDashboard::DrawTradingSection(int startY)
{
   int sX = m_x + ScaledValue(15);
   int sY = startY;
   int sectionWidth = m_width - ScaledValue(30);
   
   // Section title
   DrawLabel(sX, sY, "TRADING STATUS", m_colors.colorHighlight, "Arial Black", ScaledFontSize(12));
   DrawHorizontalLine(sX, sY + ScaledValue(18), sectionWidth, m_colors.colorBorder);
   
   sY += ScaledValue(24);
   
   // Responsive 2x2 grid
   int cardPadding = (int)(sectionWidth * m_cardPaddingRatio);
   int cardGap = (int)(sectionWidth * m_cardGapRatio);
   int cardWidth = (sectionWidth - cardPadding * 2 - cardGap) / 2;
   int cardHeight = (int)((m_height * m_sectionHeightRatio) * 0.42);
   
   // Card 1: Active Positions
   DrawBox(sX + cardPadding, sY, cardWidth, cardHeight, m_colors.colorBorder, C'30,38,48', 2);
   DrawLabel(sX + cardPadding + ScaledValue(10), sY + ScaledValue(6), 
            "Active Positions", m_colors.colorTextSecondary, "Arial", ScaledFontSize(10));
   string posText = IntegerToString(m_activePositions) + "/" + IntegerToString(m_maxPositions);
   color posColor = m_activePositions > 0 ? m_colors.colorAlertBuy : m_colors.colorNeutral;
   DrawLabel(sX + cardPadding + ScaledValue(10), sY + ScaledValue(20), 
            posText, posColor, "Arial Black", ScaledFontSize(14));
   
   // Card 2: Account Equity
   DrawBox(sX + cardPadding + cardWidth + cardGap, sY, cardWidth, cardHeight, m_colors.colorBorder, C'30,38,48', 2);
   DrawLabel(sX + cardPadding + cardWidth + cardGap + ScaledValue(10), sY + ScaledValue(6), 
            "Account Equity", m_colors.colorTextSecondary, "Arial", ScaledFontSize(10));
   DrawLabel(sX + cardPadding + cardWidth + cardGap + ScaledValue(10), sY + ScaledValue(20), 
            DoubleToString(m_equity, 2), m_colors.colorText, "Arial Black", ScaledFontSize(14));
   
   sY += cardHeight + ScaledValue(8);
   
   // Card 3: Balance
   DrawBox(sX + cardPadding, sY, cardWidth, cardHeight, m_colors.colorBorder, C'30,38,48', 2);
   DrawLabel(sX + cardPadding + ScaledValue(10), sY + ScaledValue(6), 
            "Balance", m_colors.colorTextSecondary, "Arial", ScaledFontSize(10));
   DrawLabel(sX + cardPadding + ScaledValue(10), sY + ScaledValue(20), 
            DoubleToString(m_balance, 2), m_colors.colorText, "Arial Black", ScaledFontSize(14));
   
   // Card 4: P/L Indicator
   DrawBox(sX + cardPadding + cardWidth + cardGap, sY, cardWidth, cardHeight, m_colors.colorBorder, C'30,38,48', 2);
   DrawLabel(sX + cardPadding + cardWidth + cardGap + ScaledValue(10), sY + ScaledValue(6), 
            "P/L", m_colors.colorTextSecondary, "Arial", ScaledFontSize(10));
   double pl = m_equity - m_balance;
   color plColor = pl >= 0 ? m_colors.colorPositive : m_colors.colorNegative;
   string plText = (pl >= 0 ? "+" : "") + DoubleToString(pl, 2);
   DrawLabel(sX + cardPadding + cardWidth + cardGap + ScaledValue(12), sY + ScaledValue(20), 
            plText, plColor, "Arial Black", ScaledFontSize(14));
}

//+------------------------------------------------------------------+
//| Draw Statistics Section - RESPONSIVE                            |
//+------------------------------------------------------------------+

void CProfessionalDashboard::DrawStatisticsSection(int startY)
{
   int sX = m_x + ScaledValue(15);
   int sY = startY;
   int sectionWidth = m_width - ScaledValue(30);
   
   // Section title
   DrawLabel(sX, sY, "TRADING STATISTICS", m_colors.colorHighlight, "Arial Black", ScaledFontSize(12));
   DrawHorizontalLine(sX, sY + ScaledValue(22), sectionWidth, m_colors.colorBorder);
   
   sY += ScaledValue(24);
   
   // Responsive 2x2 grid
   int cardPadding = (int)(sectionWidth * m_cardPaddingRatio);
   int cardGap = (int)(sectionWidth * m_cardGapRatio);
   int cardWidth = (sectionWidth - cardPadding * 2 - cardGap) / 2;
   int cardHeight = (int)((m_height * m_sectionHeightRatio) * 0.42);
   
   // Card 1: Total Trades
   DrawBox(sX + cardPadding, sY, cardWidth, cardHeight, m_colors.colorBorder, C'30,38,48', 2);
   DrawLabel(sX + cardPadding + ScaledValue(10), sY + ScaledValue(6), 
            "Total Trades", m_colors.colorTextSecondary, "Arial", ScaledFontSize(10));
   DrawLabel(sX + cardPadding + ScaledValue(10), sY + ScaledValue(20), 
            IntegerToString(m_totalTrades), m_colors.colorText, "Arial Black", ScaledFontSize(14));
   
   // Card 2: Win Trades
   DrawBox(sX + cardPadding + cardWidth + cardGap, sY, cardWidth, cardHeight, m_colors.colorBorder, C'30,38,48', 2);
   DrawLabel(sX + cardPadding + cardWidth + cardGap + ScaledValue(10), sY + ScaledValue(6), 
            "Win Trades", m_colors.colorTextSecondary, "Arial", ScaledFontSize(10));
   DrawLabel(sX + cardPadding + cardWidth + cardGap + ScaledValue(10), sY + ScaledValue(20), 
            IntegerToString(m_winTrades), m_colors.colorPositive, "Arial Black", ScaledFontSize(14));
   
   sY += cardHeight + ScaledValue(8);
   
   // Card 3: Avg Profit
   DrawBox(sX + cardPadding, sY, cardWidth, cardHeight, m_colors.colorBorder, C'30,38,48', 2);
   DrawLabel(sX + cardPadding + ScaledValue(10), sY + ScaledValue(6), 
            "Avg Profit/Trade", m_colors.colorTextSecondary, "Arial", ScaledFontSize(10));
   DrawLabel(sX + cardPadding + ScaledValue(10), sY + ScaledValue(20), 
            DoubleToString(m_avgProfit, 2), m_colors.colorPositive, "Arial Black", ScaledFontSize(14));
   
   // Card 4: Avg Loss
   DrawBox(sX + cardPadding + cardWidth + cardGap, sY, cardWidth, cardHeight, m_colors.colorBorder, C'30,38,48', 2);
   DrawLabel(sX + cardPadding + cardWidth + cardGap + ScaledValue(12), sY + ScaledValue(6), 
            "Avg Loss/Trade", m_colors.colorTextSecondary, "Arial", ScaledFontSize(10));
   DrawLabel(sX + cardPadding + cardWidth + cardGap + ScaledValue(12), sY + ScaledValue(20), 
            DoubleToString(MathAbs(m_avgLoss), 2), m_colors.colorNegative, "Arial Black", ScaledFontSize(14));
}

//+------------------------------------------------------------------+
//| Draw Label - Enhanced for Responsive                            |
//+------------------------------------------------------------------+

void CProfessionalDashboard::DrawLabel(int x, int y, string text, color clr, string fontName = "Arial Bold", int fontSize = 11)
{
   string labelName = GenerateObjectName("lbl", x, y);
   
   if(ObjectFind(m_chartId, labelName) != -1)
      ObjectDelete(m_chartId, labelName);
      
   if(!ObjectCreate(m_chartId, labelName, OBJ_LABEL, m_subWindow, 0, 0))
      return;
      
   ObjectSetString(m_chartId, labelName, OBJPROP_TEXT, text);
   ObjectSetString(m_chartId, labelName, OBJPROP_FONT, fontName);
   ObjectSetInteger(m_chartId, labelName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(m_chartId, labelName, OBJPROP_COLOR, clr);
   ObjectSetInteger(m_chartId, labelName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(m_chartId, labelName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(m_chartId, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(m_chartId, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(m_chartId, labelName, OBJPROP_BACK, false);
   ObjectSetInteger(m_chartId, labelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(m_chartId, labelName, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Draw Box                                                        |
//+------------------------------------------------------------------+

void CProfessionalDashboard::DrawBox(int x, int y, int width, int height, color borderColor, color bgColor, int borderWidth = 2)
{
   string boxName = GenerateObjectName("box", x, y);
   
   if(ObjectFind(m_chartId, boxName) != -1)
      ObjectDelete(m_chartId, boxName);
      
   if(!ObjectCreate(m_chartId, boxName, OBJ_RECTANGLE_LABEL, m_subWindow, 0, 0))
      return;
      
   ObjectSetInteger(m_chartId, boxName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(m_chartId, boxName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(m_chartId, boxName, OBJPROP_XSIZE, width);
   ObjectSetInteger(m_chartId, boxName, OBJPROP_YSIZE, height);
   ObjectSetInteger(m_chartId, boxName, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(m_chartId, boxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(m_chartId, boxName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(m_chartId, boxName, OBJPROP_COLOR, borderColor);
   ObjectSetInteger(m_chartId, boxName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(m_chartId, boxName, OBJPROP_WIDTH, borderWidth);
   ObjectSetInteger(m_chartId, boxName, OBJPROP_BACK, true);
   ObjectSetInteger(m_chartId, boxName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(m_chartId, boxName, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Draw Horizontal Line                                            |
//+------------------------------------------------------------------+

void CProfessionalDashboard::DrawHorizontalLine(int x, int y, int width, color clr)
{
   string lineName = GenerateObjectName("line", x, y);
   
   if(ObjectFind(m_chartId, lineName) != -1)
      ObjectDelete(m_chartId, lineName);
      
   if(!ObjectCreate(m_chartId, lineName, OBJ_RECTANGLE_LABEL, m_subWindow, 0, 0))
      return;
      
   ObjectSetInteger(m_chartId, lineName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(m_chartId, lineName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(m_chartId, lineName, OBJPROP_XSIZE, width);
   ObjectSetInteger(m_chartId, lineName, OBJPROP_YSIZE, 2);
   ObjectSetInteger(m_chartId, lineName, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(m_chartId, lineName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(m_chartId, lineName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(m_chartId, lineName, OBJPROP_BACK, false);
   ObjectSetInteger(m_chartId, lineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(m_chartId, lineName, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Cleanup                                                          |
//+------------------------------------------------------------------+

void CProfessionalDashboard::Cleanup(void)
{
   if(m_chartId == 0) return;
   
   string prefix = StringFormat("%s_%d", m_panelName, m_chartId);
   int total = ObjectsTotal(m_chartId, m_subWindow, -1);
   
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(m_chartId, i, m_subWindow);
      if(StringFind(objName, prefix) == 0)
      {
         ObjectDelete(m_chartId, objName);
      }
   }
}

//+------------------------------------------------------------------+
//| END OF FILE - Version 3.2 (FULLY FIXED FOR MT5)                 |
//+------------------------------------------------------------------+
