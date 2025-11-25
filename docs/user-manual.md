# TradingAgents 用户手册

## 1. 快速开始

### 1.1 系统要求
- Python 3.10+
- 8GB+ RAM
- 稳定的网络连接
- OpenAI API密钥
- Alpha Vantage API密钥（推荐）

### 1.2 安装步骤

#### 步骤1：克隆项目
```bash
git clone https://github.com/TauricResearch/TradingAgents.git
cd TradingAgents
```

#### 步骤2：创建虚拟环境
```bash
# 使用conda
conda create -n tradingagents python=3.13
conda activate tradingagents

# 或使用venv
python -m venv tradingagents
source tradingagents/bin/activate  # Linux/Mac
# tradingagents\Scripts\activate  # Windows
```

#### 步骤3：安装依赖
```bash
pip install -r requirements.txt
```

#### 步骤4：配置API密钥
```bash
# 方法1：环境变量
export OPENAI_API_KEY=your_openai_api_key
export ALPHA_VANTAGE_API_KEY=your_alpha_vantage_api_key

# 方法2：创建.env文件
cp .env.example .env
# 编辑.env文件，添加你的API密钥
```

### 1.3 快速验证
```bash
# 运行CLI
python -m cli.main

# 或运行示例代码
python main.py
```

## 2. CLI界面使用指南

### 2.1 启动CLI
```bash
python -m cli.main
```

### 2.2 交互式配置向导

#### 步骤1：选择股票代码
- 输入要分析的股票代码（如：AAPL, NVDA, SPY）
- 默认值：SPY
- 支持所有主要市场的股票代码

#### 步骤2：选择分析日期
- 格式：YYYY-MM-DD
- 默认值：当前日期
- 建议选择交易日

#### 步骤3：选择分析师团队
可选择以下分析师类型：
- **市场分析师**：技术分析和价格趋势
- **社交媒体分析师**：情绪分析和社交数据
- **新闻分析师**：新闻事件和宏观影响
- **基本面分析师**：财务数据和公司基本面

建议选择全部分析师以获得全面分析。

#### 步骤4：选择研究深度
- **浅层分析**：1轮辩论，快速决策
- **深度分析**：多轮辩论，详细分析
- **超深度分析**：最大辩论轮数，最全面分析

#### 步骤5：选择LLM后端
- **OpenAI**：推荐，支持所有模型
- **Anthropic**：Claude系列模型
- **Google**：Gemini系列模型
- **Ollama**：本地模型部署

#### 步骤6：选择思考代理
- **浅层思考代理**：快速响应，用于简单任务
- **深层思考代理**：深度分析，用于复杂决策

### 2.3 实时监控界面

CLI界面包含四个主要面板：

#### 进度面板
显示各团队和智能体的执行状态：
- ✅ 已完成
- 🔄 进行中
- ⏳ 等待中
- ❌ 错误

#### 消息面板
实时显示：
- 工具调用记录
- LLM推理过程
- 系统消息
- 时间戳

#### 分析面板
显示当前正在生成的分析报告：
- 市场分析报告
- 情绪分析报告
- 新闻分析报告
- 基本面分析报告
- 投资决策报告
- 交易计划
- 最终决策

#### 统计面板
显示运行统计：
- 工具调用次数
- LLM调用次数
- 生成报告数量

## 3. Python API使用指南

### 3.1 基础使用

#### 简单示例
```python
from tradingagents.graph.trading_graph import TradingAgentsGraph
from tradingagents.default_config import DEFAULT_CONFIG

# 使用默认配置
ta = TradingAgentsGraph(debug=True)

# 执行分析
final_state, decision = ta.propagate("NVDA", "2024-05-10")
print(decision)
```

#### 自定义配置示例
```python
from tradingagents.graph.trading_graph import TradingAgentsGraph
from tradingagents.default_config import DEFAULT_CONFIG

# 创建自定义配置
config = DEFAULT_CONFIG.copy()
config["deep_think_llm"] = "gpt-4o"
config["quick_think_llm"] = "gpt-4o-mini"
config["max_debate_rounds"] = 2

# 配置数据供应商
config["data_vendors"] = {
    "core_stock_apis": "yfinance",
    "technical_indicators": "yfinance", 
    "fundamental_data": "alpha_vantage",
    "news_data": "alpha_vantage",
}

# 初始化
ta = TradingAgentsGraph(debug=False, config=config)

# 执行分析
final_state, decision = ta.propagate("AAPL", "2024-05-10")
```

### 3.2 高级配置

#### 选择特定分析师
```python
# 只使用部分分析师
selected_analysts = ["market", "fundamentals"]
ta = TradingAgentsGraph(
    selected_analysts=selected_analysts,
    debug=True
)
```

#### 使用不同LLM提供商
```python
# 使用Anthropic Claude
config = DEFAULT_CONFIG.copy()
config["llm_provider"] = "anthropic"
config["deep_think_llm"] = "claude-3-opus-20240229"
config["quick_think_llm"] = "claude-3-sonnet-20240229"

ta = TradingAgentsGraph(config=config)
```

#### 本地模型配置
```python
# 使用Ollama本地模型
config = DEFAULT_CONFIG.copy()
config["llm_provider"] = "ollama"
config["backend_url"] = "http://localhost:11434/v1"
config["deep_think_llm"] = "llama2:13b"
config["quick_think_llm"] = "llama2:7b"

ta = TradingAgentsGraph(config=config)
```

### 3.3 反思和学习

#### 启用反思机制
```python
# 执行分析
final_state, decision = ta.propagate("NVDA", "2024-05-10")

# 反思和学习（基于实际收益/损失）
returns = 1000  # 实际收益值
ta.reflect_and_remember(returns)
```

#### 访问历史记忆
```python
# 记忆会自动保存到ChromaDB
# 下次运行时会自动检索相关经验
```

## 4. 配置详解

### 4.1 完整配置选项

```python
config = {
    # 目录配置
    "project_dir": "/path/to/tradingagents",
    "results_dir": "./results",
    "data_cache_dir": "./dataflows/data_cache",
    
    # LLM配置
    "llm_provider": "openai",  # openai, anthropic, google, ollama
    "deep_think_llm": "gpt-4o",
    "quick_think_llm": "gpt-4o-mini",
    "backend_url": "https://api.openai.com/v1",
    
    # 辩论配置
    "max_debate_rounds": 1,
    "max_risk_discuss_rounds": 1,
    "max_recur_limit": 100,
    
    # 数据供应商配置
    "data_vendors": {
        "core_stock_apis": "yfinance",       # yfinance, alpha_vantage, local
        "technical_indicators": "yfinance",  # yfinance, alpha_vantage, local
        "fundamental_data": "alpha_vantage", # openai, alpha_vantage, local
        "news_data": "alpha_vantage",        # openai, alpha_vantage, google, local
    },
    
    # 工具级覆盖配置
    "tool_vendors": {
        "get_stock_data": "alpha_vantage",
        "get_news": "openai",
    },
}
```

### 4.2 数据供应商选择

#### YFinance
- **优点**：免费，数据覆盖广
- **缺点**：实时性有限，有速率限制
- **适用**：历史数据，技术分析

#### Alpha Vantage
- **优点**：数据质量高，实时性好
- **缺点**：免费版有速率限制
- **适用**：基本面数据，新闻数据

#### OpenAI
- **优点**：集成度高，数据质量好
- **缺点**：成本较高
- **适用**：新闻和基本面数据

#### Google News
- **优点**：新闻覆盖广，免费
- **缺点**：结构化程度低
- **适用**：新闻情绪分析

#### 本地数据
- **优点**：速度快，无API限制
- **缺点**：数据可能过时
- **适用**：回测，离线分析

## 5. 输出解读

### 5.1 分析报告结构

#### 分析师团队报告
```
## 市场分析
- 技术指标分析
- 价格趋势判断
- 关键支撑阻力位

## 社交情绪分析  
- 情绪指标评分
- 社交媒体热点
- 情绪趋势变化

## 新闻分析
- 重大新闻事件
- 宏观经济影响
- 行业动态分析

## 基本面分析
- 财务健康状况
- 估值水平分析
- 成长性评估
```

#### 投资决策报告
```
## 研究团队决策
- 牛市观点理由
- 熊市观点理由
- 综合投资建议
- 风险评估
```

#### 交易计划
```
## 交易团队计划
- 建议仓位大小
- 入场时机选择
- 止损止盈策略
- 持有期限建议
```

#### 最终决策
```
## 投资组合管理决策
- 最终交易决定
- 风险控制措施
- 资金配置建议
- 执行优先级
```

### 5.2 决策信号处理

```python
# 获取简化信号
signal = ta.process_signal(final_state["final_trade_decision"])

# 信号类型通常包括：
# - "BUY": 建议买入
# - "SELL": 建议卖出  
# - "HOLD": 建议持有
# - "STRONG_BUY": 强烈建议买入
# - "STRONG_SELL": 强烈建议卖出
```

## 6. 最佳实践

### 6.1 分析师选择策略
- **短期交易**：市场分析师 + 社交媒体分析师
- **长期投资**：基本面分析师 + 新闻分析师
- **全面分析**：选择所有分析师
- **快速决策**：减少分析师数量

### 6.2 模型选择建议
- **成本敏感**：使用mini版本的模型
- **质量优先**：使用最新版本的模型
- **速度优先**：使用快速模型进行浅层分析
- **深度分析**：使用强大模型进行深度思考

### 6.3 数据源配置
- **生产环境**：Alpha Vantage Premium
- **开发测试**：YFinance + Alpha Vantage免费版
- **离线分析**：本地数据源
- **实时交易**：多个数据源冗余

### 6.4 性能优化
- 合理设置辩论轮数
- 使用缓存机制
- 选择合适的模型
- 监控API使用量

## 7. 故障排除

### 7.1 常见问题

#### API密钥问题
```bash
# 检查环境变量
echo $OPENAI_API_KEY
echo $ALPHA_VANTAGE_API_KEY

# 检查.env文件
cat .env
```

#### 网络连接问题
```bash
# 测试API连接
curl -H "Authorization: Bearer $OPENAI_API_KEY" \
     https://api.openai.com/v1/models
```

#### 内存不足
- 减少同时运行的智能体数量
- 使用较小的模型
- 清理缓存数据

#### 速率限制
- 升级API订阅
- 使用多个API密钥
- 添加重试机制

### 7.2 调试技巧

#### 启用调试模式
```python
ta = TradingAgentsGraph(debug=True)
```

#### 查看详细日志
```python
# 检查日志文件
tail -f eval_results/TICKER/TradingAgentsStrategy_logs/full_states_log_DATE.json
```

#### 监控资源使用
```bash
# 监控内存使用
htop

# 监控网络使用
iftop
```

这个用户手册提供了从安装到高级使用的完整指南，帮助用户充分利用TradingAgents框架的强大功能。