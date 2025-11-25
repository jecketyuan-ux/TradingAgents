#!/bin/bash
# 文档验证脚本

echo "=== TradingAgents 文档验证 ==="
echo

# 检查所有必需的文档文件是否存在
echo "1. 检查文档文件完整性..."
required_files=(
    "README.md"
    "INDEX.md" 
    "architecture-design.md"
    "user-manual.md"
    "deployment-manual.md"
    "operations-manual.md"
    "process-flow-diagrams.md"
    "system-architecture-overview.md"
    "PROJECT-SUMMARY.md"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file (缺失)"
        missing_files+=("$file")
    fi
done

echo
if [ ${#missing_files[@]} -eq 0 ]; then
    echo "✅ 所有必需的文档文件都已创建"
else
    echo "❌ 缺失 ${#missing_files[@]} 个文件: ${missing_files[*]}"
fi

# 检查文档文件大小
echo
echo "2. 检查文档文件大小..."
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        size=$(wc -c < "$file")
        lines=$(wc -l < "$file")
        echo "📄 $file: $size 字节, $lines 行"
    fi
done

# 检查Mermaid图表语法
echo
echo "3. 检查Mermaid图表语法..."
mermaid_files=("architecture-design.md" "process-flow-diagrams.md" "system-architecture-overview.md")

for file in "${mermaid_files[@]}"; do
    if [ -f "$file" ]; then
        echo "🔍 检查 $file 中的Mermaid图表..."
        # 简单检查mermaid代码块
        mermaid_blocks=$(grep -c '```mermaid' "$file" 2>/dev/null || echo "0")
        echo "   发现 $mermaid_blocks 个Mermaid代码块"
        
        # 检查常见的mermaid语法错误
        if grep -q 'graph TD\|flowchart TD\|stateDiagram\|sequenceDiagram' "$file"; then
            echo "   ✅ 包含有效的Mermaid图表类型"
        else
            echo "   ⚠️  未检测到标准Mermaid图表类型"
        fi
    fi
done

# 检查文档链接
echo
echo "4. 检查文档内部链接..."
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        # 检查相对链接
        relative_links=$(grep -o '\[.*\](\.\/[^)]*)' "$file" | wc -l)
        if [ "$relative_links" -gt 0 ]; then
            echo "🔗 $file: 发现 $relative_links 个相对链接"
        fi
    fi
done

# 生成文档统计
echo
echo "5. 生成文档统计..."
total_lines=0
total_files=0

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file")
        total_lines=$((total_lines + lines))
        total_files=$((total_files + 1))
    fi
done

echo "📊 文档统计:"
echo "   总文件数: $total_files"
echo "   总行数: $total_lines"
echo "   平均行数: $((total_lines / total_files))"

# 检查文档结构
echo
echo "6. 检查文档结构..."
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        # 检查标题结构
        h1_count=$(grep -c '^# ' "$file" 2>/dev/null || echo "0")
        h2_count=$(grep -c '^## ' "$file" 2>/dev/null || echo "0")
        h3_count=$(grep -c '^### ' "$file" 2>/dev/null || echo "0")
        
        echo "📝 $file: H1:$h1_count, H2:$h2_count, H3:$h3_count"
    fi
done

echo
echo "=== 文档验证完成 ==="

# 生成验证报告
cat > docs-verification-report.md << EOF
# TradingAgents 文档验证报告

**验证时间**: $(date)
**验证状态**: ${#missing_files[@]} -eq 0 && "✅ 通过" || "❌ 失败"

## 文件清单

| 文件名 | 状态 | 大小 | 行数 |
|--------|------|------|------|
EOF

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        size=$(wc -c < "$file")
        lines=$(wc -l < "$file")
        echo "| $file | ✅ | $size | $lines |" >> docs-verification-report.md
    else
        echo "| $file | ❌ | - | - |" >> docs-verification-report.md
    fi
done

cat >> docs-verification-report.md << EOF

## 统计信息

- **总文件数**: $total_files
- **总行数**: $total_lines
- **平均行数**: $((total_lines / total_files))

## 验证结果

${#missing_files[@]} -eq 0 && "✅ 所有文档验证通过" || "❌ 存在缺失文件"

EOF

echo "📄 验证报告已生成: docs-verification-report.md"