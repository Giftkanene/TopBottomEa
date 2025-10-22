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
