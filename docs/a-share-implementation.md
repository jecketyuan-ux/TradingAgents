# TradingAgents A股实现代码

## 1. A股数据适配器

### 1.1 Tushare适配器

```python
# tradingagents/dataflows/tushare_adapter.py
import tushare as ts
import pandas as pd
from typing import Optional

class TushareAdapter:
    """Tushare数据适配器"""
    
    def __init__(self, token: str):
        """初始化Tushare适配器"""
        ts.set_token(token)
        self.pro = ts.pro_api()
    
    def get_stock_data(self, symbol: str, start_date: str, end_date: str) -> Optional[str]:
        """获取A股历史数据"""
        try:
            # 获取日线数据
            df = self.pro.daily(
                ts_code=symbol,
                start_date=start_date.replace('-', ''),
                end_date=end_date.replace('-', '')
            )
            
            if df.empty:
                return f"No data found for {symbol}"
            
            # 格式化数据
            df = df.sort_values('trade_date')
            df = df.rename(columns={
                'trade_date': 'Date',
                'open': 'Open',
                'high': 'High', 
                'low': 'Low',
                'close': 'Close',
                'vol': 'Volume'
            })
            
            return df.to_csv(index=False)
            
        except Exception as e:
            return f"Error retrieving data: {str(e)}"
    
    def get_realtime_quote(self, symbol: str) -> dict:
        """获取实时行情（需要高级权限）"""
        return {
            'error': 'Real-time data requires premium subscription',
            'symbol': symbol,
            'message': 'Please use AkShare for real-time quotes'
        }
```

### 1.2 AkShare适配器

```python
# tradingagents/dataflows/akshare_adapter.py
import akshare as ak
import pandas as pd
from typing import Dict

class AkShareAdapter:
    """AkShare数据适配器"""
    
    def __init__(self):
        """初始化AkShare适配器"""
        pass
    
    def get_stock_data(self, symbol: str, start_date: str, end_date: str) -> Optional[str]:
        """获取A股历史数据"""
        try:
            df = ak.stock_zh_a_hist(
                symbol=symbol,
                start_date=start_date,
                end_date=end_date
            )
            
            if df.empty:
                return f"No data found for {symbol}"
            
            # 格式化数据
            df = df.rename(columns={
                '日期': 'Date',
                '开盘': 'Open',
                '最高': 'High',
                '最低': 'Low',
                '收盘': 'Close',
                '成交量': 'Volume'
            })
            
            return df.to_csv(index=False)
            
        except Exception as e:
            return f"Error retrieving data: {str(e)}"
    
    def get_realtime_quote(self, symbol: str) -> Dict:
        """获取实时行情"""
        try:
            df = ak.stock_zh_a_spot_em()
            stock_data = df[df['代码'] == symbol]
            
            if stock_data.empty:
                return {'error': f'Stock {symbol} not found'}
            
            stock = stock_data.iloc[0]
            
            return {
                'symbol': symbol,
                'name': stock['名称'],
                'price': float(stock['最新价']),
                'change': float(stock['涨跌额']),
                'change_percent': float(stock['涨跌幅']),
                'volume': int(stock['成交量']),
                'amount': float(stock['成交额']),
                'high': float(stock['最高']),
                'low': float(stock['最低']),
                'open': float(stock['今开']),
                'yesterday_close': float(stock['昨收'])
            }
            
        except Exception as e:
            return {'error': f'Error getting quote: {str(e)}'}
```

## 2. A股交易规则引擎

```python
# tradingagents/trading/a_share_rules.py
from datetime import datetime, timedelta

class AShareTradingRules:
    """A股交易规则引擎"""
    
    def __init__(self):
        """初始化交易规则"""
        # 涨跌停限制
        self.price_limits = {
            'normal': 0.10,    # 普通股票涨跌幅限制
            'st': 0.05,        # ST股票涨跌幅限制
            'gem': 0.20,       # 创业板涨跌幅限制
            'star': 0.20,      # 科创板涨跌幅限制
            'bse': 0.30,       # 北交所涨跌幅限制
        }
        
        # 交易费用
        self.commission_rate = 0.00025    # 佣金费率
        self.stamp_tax_rate = 0.001       # 印花税率
        self.transfer_fee_rate = 0.00002  # 过户费率
        self.min_commission = 5           # 最低佣金
        
        # 交易规则
        self.min_lot_size = 100          # 最小交易单位
    
    def validate_order(self, symbol: str, side: str, quantity: int, 
                     price: float, current_time: datetime = None) -> dict:
        """验证订单有效性"""
        # 检查交易时间
        if not self._is_trading_time(current_time):
            return {
                'valid': False,
                'error': '非交易时间',
                'error_code': 'MARKET_CLOSED'
            }
        
        # 检查最小交易单位
        if quantity % self.min_lot_size != 0:
            return {
                'valid': False,
                'error': f'交易数量必须是{self.min_lot_size}的倍数',
                'error_code': 'INVALID_QUANTITY'
            }
        
        # 检查涨跌停
        limit_check = self._check_price_limit(symbol, price)
        
        if side == 'buy' and not limit_check['can_buy']:
            return {
                'valid': False,
                'error': f'价格超过涨停板{limit_check["max_price"]:.2f}',
                'error_code': 'PRICE_LIMIT_UP'
            }
        elif side == 'sell' and not limit_check['can_sell']:
            return {
                'valid': False,
                'error': f'价格低于跌停板{limit_check["min_price"]:.2f}',
                'error_code': 'PRICE_LIMIT_DOWN'
            }
        
        return {
            'valid': True,
            'error': None,
            'error_code': 'None'
        }
    
    def calculate_trading_fees(self, symbol: str, price: float, 
                           quantity: int, side: str) -> dict:
        """计算交易费用"""
        amount = price * quantity
        
        # 佣金（双向收取）
        commission = max(amount * self.commission_rate, self.min_commission)
        
        # 印花税（仅卖出收取）
        stamp_tax = amount * self.stamp_tax_rate if side == 'sell' else 0
        
        # 过户费（仅沪市收取）
        transfer_fee = amount * self.transfer_fee_rate if self._is_sh_stock(symbol) else 0
        
        total_fees = commission + stamp_tax + transfer_fee
        
        return {
            'commission': commission,
            'stamp_tax': stamp_tax,
            'transfer_fee': transfer_fee,
            'total_fees': total_fees,
            'net_amount': amount - total_fees if side == 'buy' else amount - total_fees,
            'fee_rate': total_fees / amount if amount > 0 else 0
        }
    
    def check_t_plus1(self, symbol: str, buy_date: str, sell_date: str) -> dict:
        """检查T+1交易限制"""
        buy_dt = datetime.strptime(buy_date, "%Y-%m-%d")
        sell_dt = datetime.strptime(sell_date, "%Y-%m-%d")
        
        # 计算最早可卖出日期
        min_sell_date = self._get_next_trading_day(buy_date)
        
        can_sell = sell_dt >= datetime.strptime(min_sell_date, "%Y-%m-%d")
        
        return {
            'can_sell': can_sell,
            'min_sell_date': min_sell_date,
            'days_to_sell': (sell_dt - buy_dt).days
        }
    
    def _get_stock_type(self, symbol: str) -> str:
        """判断股票类型"""
        if symbol.startswith('688'):
            return 'star'      # 科创板
        elif symbol.startswith('300') or symbol.startswith('301'):
            return 'gem'       # 创业板
        elif symbol.startswith('8') or symbol.startswith('4'):
            return 'bse'       # 北交所
        elif 'ST' in symbol.upper():
            return 'st'        # ST股票
        else:
            return 'normal'    # 普通股票
    
    def _is_sh_stock(self, symbol: str) -> bool:
        """判断是否为沪市股票"""
        return symbol.startswith('6') or symbol.startswith('688')
    
    def _is_trading_time(self, current_time: datetime = None) -> bool:
        """判断是否为交易时间"""
        if current_time is None:
            current_time = datetime.now()
        
        # 检查是否为交易日
        if not self._is_trading_day(current_time.strftime("%Y-%m-%d")):
            return False
        
        # 检查是否在交易时间段内
        time_str = current_time.strftime("%H:%M")
        
        return ('09:30' <= time_str <= '11:30') or ('13:00' <= time_str <= '15:00')
    
    def _is_trading_day(self, date: str) -> bool:
        """判断是否为交易日"""
        try:
            date_obj = datetime.strptime(date, "%Y-%m-%d")
            
            # 检查是否为周末
            if date_obj.weekday() >= 5:
                return False
            
            # 简化起见，这里可以加载节假日数据
            # 2024年主要节假日
            holidays_2024 = {
                '2024-01-01', '2024-02-10', '2024-02-11', '2024-02-12',
                '2024-04-04', '2024-04-05', '2024-04-06',
                '2024-05-01', '2024-05-02', '2024-05-03',
                '2024-06-10', '2024-10-01', '2024-10-02', '2024-10-03'
            }
            
            return date not in holidays_2024
            
        except:
            return False
    
    def _get_next_trading_day(self, date: str) -> str:
        """获取下一个交易日"""
        current_date = datetime.strptime(date, "%Y-%m-%d")
        next_date = current_date + timedelta(days=1)
        
        # 找到下一个交易日
        while not self._is_trading_day(next_date.strftime("%Y-%m-%d")):
            next_date += timedelta(days=1)
        
        return next_date.strftime("%Y-%m-%d")
    
    def _check_price_limit(self, symbol: str, price: float, 
                        reference_price: float = None) -> dict:
        """检查涨跌停限制"""
        if reference_price is None:
            # 如果没有提供参考价格，使用当前价格估算
            reference_price = price * 0.98  # 简单估算
        
        # 判断股票类型
        stock_type = self._get_stock_type(symbol)
        limit_rate = self.price_limits.get(stock_type, 0.10)
        
        max_price = reference_price * (1 + limit_rate)
        min_price = reference_price * (1 - limit_rate)
        
        return {
            'can_buy': price < max_price,
            'can_sell': price > min_price,
            'max_price': max_price,
            'min_price': min_price,
            'limit_rate': limit_rate,
            'stock_type': stock_type
        }
```

## 3. A股模拟交易引擎

```python
# tradingagents/trading/a_share_simulator.py
import uuid
from datetime import datetime
from typing import Dict, Optional
from decimal import Decimal

from .a_share_rules import AShareTradingRules
from ..dataflows.akshare_adapter import AkShareAdapter

class AShareSimulator:
    """A股模拟交易引擎"""
    
    def __init__(self, initial_capital: float = 1000000):
        """初始化模拟交易引擎"""
        self.initial_capital = initial_capital
        self.current_capital = initial_capital
        self.available_capital = initial_capital
        
        # 持仓和订单管理
        self.positions = {}      # 持仓信息
        self.orders = []         # 订单历史
        self.trades = []         # 成交记录
        self.daily_pnl = []      # 每日盈亏记录
        
        # 初始化组件
        self.trading_rules = AShareTradingRules()
        self.data_adapter = AkShareAdapter()
    
    def place_order(self, symbol: str, side: str, quantity: int, 
                   order_type: str = 'market', price: Optional[float] = None) -> dict:
        """下单"""
        order_id = str(uuid.uuid4())
        current_time = datetime.now()
        
        # 获取当前价格
        if price is None:
            quote = self.data_adapter.get_realtime_quote(symbol)
            if 'error' in quote:
                return {'success': False, 'error': f"获取实时行情失败: {quote['error']}"}
            current_price = quote['price']
        else:
            current_price = price
        
        # 验证订单
        validation = self.trading_rules.validate_order(
            symbol, side, quantity, current_price, current_time
        )
        if not validation['valid']:
            return {'success': False, 'error': validation['error']}
        
        # 创建订单
        order = {
            'order_id': order_id,
            'symbol': symbol,
            'side': side,
            'quantity': quantity,
            'order_type': order_type,
            'price': current_price,
            'status': 'pending',
            'created_at': current_time,
            'updated_at': current_time
        }
        
        self.orders.append(order)
        
        # 执行订单
        execution_result = self._execute_order(order)
        
        return {
            'success': execution_result['success'],
            'order_id': order_id,
            'message': execution_result['message'],
            'trade_id': execution_result.get('trade_id')
        }
    
    def _execute_order(self, order: dict) -> dict:
        """执行订单"""
        try:
            symbol = order['symbol']
            side = order['side']
            quantity = order['quantity']
            price = order['price']
            
            # 计算交易费用
            fees = self.trading_rules.calculate_trading_fees(symbol, price, quantity, side)
            
            # 计算总金额
            total_amount = price * quantity + fees['total_fees']
            
            if side == 'buy':
                # 买入订单
                if self.available_capital < total_amount:
                    return {
                        'success': False,
                        'message': '资金不足',
                        'required_capital': total_amount,
                        'available_capital': self.available_capital
                    }
                
                # 扣除资金
                self.current_capital -= total_amount
                self.available_capital -= total_amount
                
                # 更新持仓
                self._update_position(symbol, quantity, price, fees['total_fees'])
                
            else:  # sell
                # 卖出订单
                if symbol not in self.positions or self.positions[symbol]['quantity'] < quantity:
                    return {
                        'success': False,
                        'message': '持仓不足',
                        'required_quantity': quantity,
                        'available_quantity': self.positions.get(symbol, {}).get('quantity', 0)
                    }
                
                # 计算收益
                position = self.positions[symbol]
                cost_basis = self._get_position_cost(position, quantity)
                proceeds = price * quantity - fees['total_fees']
                pnl = proceeds - cost_basis
                
                # 更新资金
                self.current_capital += proceeds
                self.available_capital += proceeds
                
                # 更新持仓
                self._reduce_position(symbol, quantity, cost_basis)
                
                # 记录盈亏
                self._record_pnl(symbol, pnl, side, price, quantity)
            
            # 记录成交
            trade = {
                'trade_id': str(uuid.uuid4()),
                'order_id': order['order_id'],
                'symbol': symbol,
                'side': side,
                'quantity': quantity,
                'price': price,
                'fees': fees,
                'pnl': pnl if side == 'sell' else 0,
                'executed_at': datetime.now()
            }
            
            self.trades.append(trade)
            
            # 更新订单状态
            order['status'] = 'executed'
            order['executed_at'] = datetime.now()
            order['updated_at'] = datetime.now()
            
            return {
                'success': True,
                'message': '订单执行成功',
                'trade_id': trade['trade_id'],
                'executed_price': price,
                'fees': fees
            }
            
        except Exception as e:
            return {
                'success': False,
                'message': f'订单执行失败: {str(e)}'
            }
    
    def get_portfolio_value(self) -> dict:
        """获取投资组合价值"""
        total_value = self.current_capital
        position_details = {}
        
        for symbol, position in self.positions.items():
            try:
                # 获取当前价格
                quote = self.data_adapter.get_realtime_quote(symbol)
                if 'error' in quote:
                    current_price = position.get('avg_cost', 0)
                else:
                    current_price = quote['price']
                
                # 计算持仓价值
                market_value = current_price * position['quantity']
                cost_basis = position['total_cost']
                unrealized_pnl = market_value - cost_basis
                unrealized_pnl_percent = (unrealized_pnl / cost_basis) * 100 if cost_basis > 0 else 0
                
                position_details[symbol] = {
                    'quantity': position['quantity'],
                    'avg_cost': position['avg_cost'],
                    'current_price': current_price,
                    'market_value': market_value,
                    'cost_basis': cost_basis,
                    'unrealized_pnl': unrealized_pnl,
                    'unrealized_pnl_percent': unrealized_pnl_percent,
                    'weight': market_value / (total_value + market_value) if (total_value + market_value) > 0 else 0
                }
                
                total_value += market_value
                
            except Exception as e:
                print(f"计算持仓价值失败 {symbol}: {e}")
                continue
        
        # 计算总收益
        total_pnl = total_value - self.initial_capital
        total_pnl_percent = (total_pnl / self.initial_capital) * 100
        
        return {
            'total_value': total_value,
            'cash': self.current_capital,
            'available_cash': self.available_capital,
            'positions': position_details,
            'total_pnl': total_pnl,
            'total_pnl_percent': total_pnl_percent,
            'position_count': len(position_details),
            'initial_capital': self.initial_capital
        }
    
    def get_performance_summary(self) -> dict:
        """获取绩效摘要"""
        portfolio = self.get_portfolio_value()
        
        # 交易统计
        total_trades = len(self.trades)
        winning_trades = len([t for t in self.trades if t.get('pnl', 0) > 0])
        losing_trades = len([t for t in self.trades if t.get('pnl', 0) < 0])
        
        win_rate = (winning_trades / total_trades) * 100 if total_trades > 0 else 0
        
        # 收益统计
        realized_pnl = sum([t.get('pnl', 0) for t in self.trades])
        unrealized_pnl = sum([p.get('unrealized_pnl', 0) for p in portfolio['positions'].values()])
        
        # 费用统计
        total_fees = sum([t['fees']['total_fees'] for t in self.trades])
        
        return {
            'total_trades': total_trades,
            'winning_trades': winning_trades,
            'losing_trades': losing_trades,
            'win_rate': win_rate,
            'realized_pnl': realized_pnl,
            'unrealized_pnl': unrealized_pnl,
            'total_pnl': portfolio['total_pnl'],
            'total_fees': total_fees,
            'total_return': portfolio['total_pnl_percent'],
            'current_value': portfolio['total_value']
        }
    
    # 私有方法
    def _update_position(self, symbol: str, quantity: int, price: float, fees: float):
        """更新持仓"""
        if symbol not in self.positions:
            self.positions[symbol] = {
                'quantity': 0,
                'avg_cost': 0,
                'total_cost': 0,
                'buy_dates': []
            }
        
        position = self.positions[symbol]
        total_amount = price * quantity + fees
        
        # 更新持仓
        old_quantity = position['quantity']
        old_total_cost = position['total_cost']
        
        new_quantity = old_quantity + quantity
        new_total_cost = old_total_cost + total_amount
        new_avg_cost = new_total_cost / new_quantity
        
        self.positions[symbol] = {
            'quantity': new_quantity,
            'avg_cost': new_avg_cost,
            'total_cost': new_total_cost,
            'buy_dates': position['buy_dates'] + [datetime.now().strftime('%Y-%m-%d')] * quantity
        }
    
    def _reduce_position(self, symbol: str, quantity: int, cost_basis: float):
        """减少持仓"""
        if symbol not in self.positions:
            return
        
        position = self.positions[symbol]
        remaining_quantity = position['quantity'] - quantity
        
        if remaining_quantity == 0:
            del self.positions[symbol]
        else:
            # 按比例减少成本
            cost_reduction = (quantity / position['quantity']) * position['total_cost']
            remaining_cost = position['total_cost'] - cost_reduction
            
            self.positions[symbol] = {
                'quantity': remaining_quantity,
                'avg_cost': remaining_cost / remaining_quantity,
                'total_cost': remaining_cost,
                'buy_dates': position['buy_dates'][quantity:]  # 移除最早买入的日期
            }
    
    def _get_position_cost(self, position: dict, quantity: int) -> float:
        """获取持仓成本"""
        return position['avg_cost'] * quantity
    
    def _record_pnl(self, symbol: str, pnl: float, side: str, price: float, quantity: int):
        """记录盈亏"""
        self.daily_pnl.append({
            'date': datetime.now().strftime('%Y-%m-%d'),
            'symbol': symbol,
            'side': side,
            'pnl': pnl,
            'price': price,
            'quantity': quantity
        })
```

## 4. 使用示例

```python
# 示例：A股模拟交易
from tradingagents.trading.a_share_simulator import AShareSimulator

def main():
    # 初始化模拟器
    simulator = AShareSimulator(initial_capital=1000000)
    
    print("=== A股模拟交易开始 ===")
    print(f"初始资金: {simulator.initial_capital:,.0f}元")
    
    # 示例交易
    trades = [
        {'symbol': '000001', 'side': 'buy', 'quantity': 1000},  # 买入平安银行
        {'symbol': '000002', 'side': 'buy', 'quantity': 500},   # 买入万科A
        {'symbol': '000001', 'side': 'sell', 'quantity': 500},  # 卖出部分平安银行
    ]
    
    for i, trade in enumerate(trades, 1):
        print(f"\n--- 交易 {i} ---")
        print(f"交易: {trade}")
        
        result = simulator.place_order(**trade)
        print(f"结果: {result}")
        
        # 显示当前投资组合
        portfolio = simulator.get_portfolio_value()
        print(f"当前总价值: {portfolio['total_value']:,.0f}元")
        print(f"当前盈亏: {portfolio['total_pnl']:+,.0f}元 ({portfolio['total_pnl_percent']:+.2f}%)")
    
    # 显示最终绩效
    performance = simulator.get_performance_summary()
    print(f"\n=== 交易绩效摘要 ===")
    for key, value in performance.items():
        if isinstance(value, float):
            print(f"{key}: {value:,.4f}")
        else:
            print(f"{key}: {value}")

if __name__ == "__main__":
    main()
```

## 5. 配置文件

```python
# a_share_config.py
import os

A_SHARE_CONFIG = {
    # 基础配置
    'initial_capital': 1000000,      # 初始资金
    'primary_source': 'akshare',      # 主要数据源
    'fallback_source': 'tushare',     # 备用数据源
    'tushare_token': os.getenv('TUSHARE_TOKEN', ''),
    
    # 交易规则配置
    'commission_rate': 0.00025,     # 佣金费率
    'slippage_rate': 0.001,        # 滑点率
    'enable_short': False,            # 是否允许做空
    'enable_margin': False,           # 是否允许融资融券
    
    # 风险控制配置
    'max_position_size': 0.10,       # 单股最大仓位
    'max_total_position': 0.95,     # 最大总仓位
    'stop_loss_rate': 0.05,         # 止损比例
    'take_profit_rate': 0.20,       # 止盈比例
    'max_daily_loss': 0.02,         # 日最大亏损
}
```

这套A股实现代码提供了完整的数据接入、交易规则和模拟交易功能，可以作为TradingAgents项目接入A股市场的基础框架。