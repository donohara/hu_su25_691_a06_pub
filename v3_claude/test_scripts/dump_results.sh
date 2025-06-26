# Extract all results fields
jq '.results' your_data.json

# Get paper titles
jq '.results.papers[].title' your_data.json

# Get papers with analysis
jq '.results.papers[] | {title: .title, analysis: .analysis}' your_data.json

# Get synthesis summary
jq '.results.synthesis' your_data.json

# Get classifications
jq '.results.classifications' your_data.json

# Count papers found
jq '.results.papers_found' your_data.json

# Get processing time
jq '.results.processing_time' your_data.json

# Pretty print entire results
jq '.results' your_data.json | jq .