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
input int     Magic                  = 1000;
input string  CommentName            ="TopBottomEa";

//+------------------------------------------------------------------+
//| Input Dependent Variables                                        |
//+------------------------------------------------------------------+
int     VolatilityThreshold   = Volatility;     // volatility settings 
int     StopLossPoints        = StopLoss;       // sl in pips           
int     TakeProfitPoints      = Profit;         // tp in pips 
int     MaxBandWidth          = 1000;           // bollinger max bandwidth
int     MinBandwidth          = 150;            // bollinger min bandwidth 
double  CalculateLotSize      = 0.0;            // dynamic lot calculations 

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
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   
  }
