//+------------------------------------------------------------------+
//|                                                    TopBottom.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Include files                                                    |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
  CTrade          trade;
  CPositionInfo   posinfo;
  COrderInfo      ordinfo;

//+------------------------------------------------------------------+
//| Input variables                                                  |
//+------------------------------------------------------------------+
input double  Lots                   = 0.1;             //Lot Size
input bool    CompoundIntrestSwitch  = false;           //Risk in base point instead of fixed lots 
input int     Risk                   = 40;              //Risk per trade in base points 
input bool    ParameterSwitching     = false;           //Different settings for different pairs 
input int     Volatility             = 110;             //Volutility for williams %R period
input int     StopLoss               = 800;
input int     Profit                 = 300;
input double  PointDifferenceLimit   = 50.0;            //Max spread allowed in points
input bool    DisplaySwitch          = true; 
input int     Magic                  = 1000;
input string  CommentName            ="TopBottomEa";

//+------------------------------------------------------------------+
//| Input Dependent Variables                                        |
//+------------------------------------------------------------------+
int     volatilityThreshold   = Volatility;     // volatility settings 
int     stopLossPoints        = StopLoss;       // sl in pips           
int     takeProfitPoints      = Profit;         // tp in pips 
int     maxBandWidth          = 1000;           // bollinger max bandwidth
int     minBandwidth          = 150;            // bollinger min bandwidth 
double  calculateLotSize      = 0.0;            // dynamic lot calculations 

//+------------------------------------------------------------------+
//| Account/Trading Parameters                                       |
//+------------------------------------------------------------------+
double  accountBalanceDivisor   = 1000000;      //risk calculations 
int     maxSlippage             = 30;           //max allowed slippage 
bool    tradingAllowed          = true;         //master trading switch

//+------------------------------------------------------------------+
//| Indicator parameteres                                            |
//+------------------------------------------------------------------+

int  wraThreshold            = 5;
int  handleBollinger;
int  handleWRP;

//+------------------------------------------------------------------+
//| Time Management                                                  |
//+------------------------------------------------------------------+
int         startTradingHour1   = 20;
int         endTradingHour1     = 24;
int         startTradingHour2   = 0;
int         endTradingHour2     = 3;
datetime    lastSignalTime      = 0;
datetime    lastBarTime         = 0;      // current bar timestamp
MqlDateTime BrokerTime, GMTTime;          // Time Structures 


//+------------------------------------------------------------------+
//| Position Tracking                                                |
//+------------------------------------------------------------------+
int buyPositionCount  = 0;      // we will use these to check how many buy or sell positions are there before placing an order 
int sellPositionCount = 0;  

//+------------------------------------------------------------------+
//| lot and price managment                                          |
//+------------------------------------------------------------------+
double totalBuyLots     = 0.0;      // total buy volume 
double totalSellLots    = 0.0;      // total sell volume 
double buyPrice         = 0.0;      // avg buy entry
double sellPrice        = 0.0;      // avg sell entry 
double buyStopLoss      = 0.0;      // buy sl price 
double sellStopLoss     = 0.0;      // sell sl price 

//+------------------------------------------------------------------+
//| Profit Tracking                                                  |
//+------------------------------------------------------------------+
double totalBuyProfit   = 0.0;    // Buy PnL
double totalSellProfit  = 0.0;    // Sell PnL


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){

  trade.SetExpertMagicNumber(Magic);
  ChartSetInteger(0,CHART_SHOW_GRID,false); // removes the gridlines from the chart the ea is running on 

  //function to set up parameter switching 
  if(ParameterSwitching){
    if(StringFind(_Symbol,"CHFSGD",0) < 0 && StringFind(_Symbol,"GBPSGD",0) < 0){
      // if these pairs are not found then these values should be used 
      volatilityThreshold   = Volatility;
      stopLossPoints = StopLoss;
      takeProfitPoints = Profit;
      maxBandWidth = 1000;
      minBandwidth = 150;
    }
    else{
      // if the pairs are found then these values will be set 
      volatilityThreshold = 35;
      stopLossPoints = StopLoss;
      takeProfitPoints = Profit;
      maxBandWidth = 1000;
      minBandwidth = 0;
    }
  }
  else{
    if(StringFind(_Symbol,"GBPCAD",0) >= 0){
      // default values for GBPCAD
      volatilityThreshold = 110;
      stopLossPoints = 800;
      takeProfitPoints = 300;
      maxBandWidth = 1000;
      minBandwidth = 150;
    }
    if(StringFind(_Symbol,"EURSGD",0) >= 0){
      volatilityThreshold = 140;
      stopLossPoints = 700;
      takeProfitPoints = 160;
      maxBandWidth = 1000;
      minBandwidth = 150;
    }
    if(StringFind(_Symbol,"GBPCHF",0) >= 0){
      volatilityThreshold = 110;
      stopLossPoints = 600;
      takeProfitPoints = 200;
      maxBandWidth = 1000;
      minBandwidth = 150;
    }
    if(StringFind(_Symbol,"CHFSGD",0) >= 0){
      volatilityThreshold = 60;
      stopLossPoints = 700;
      takeProfitPoints = 160;
      maxBandWidth = 1000;
      minBandwidth = 0;
    }
    if(StringFind(_Symbol,"GBPSGD",0) >= 0){
      volatilityThreshold = 35;
      stopLossPoints = 700;
      takeProfitPoints = 160;
      maxBandWidth = 1000;
      minBandwidth = 0;
    }
  }
    // hide the indicators 
    TesterHideIndicators(true);

    // asign indicator handles 
    handleBollinger = iBands(_Symbol,PERIOD_M1,20,0,2.0,PRICE_CLOSE);
    handleWRP       = iWPR(_Symbol,PERIOD_M1,volatilityThreshold);

    //show the display panel
    if(DisplaySwitch){
      //CreateDisplayPanel();
    }

  
  return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
    // remove all the objects from the charts
    ObjectDelete(0,"tb_");
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){

  // variables 
  double upperBolligerBand, lowerBolllingerBand, currentWPR, indBuffer[];
  
  // copy the indicater values into the defined arrays
  CopyBuffer(handleBollinger,1,0,1,indBuffer);  // MODE_UPPER
  upperBolligerBand = indBuffer[0];

  CopyBuffer(handleBollinger,2,0,1,indBuffer);  // MODE_LOWER
  lowerBolllingerBand = indBuffer[0];

  CopyBuffer(handleWRP,0,0,1,indBuffer);      //WPR value
  currentWPR = indBuffer[0];


  // buy and sell logic

   
}
