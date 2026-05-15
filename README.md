# 🤖 AI Job Search Agent

An AI-powered agent that analyzes job postings and automatically 
generates tailored resumes and cover letters using the Claude API.

## What It Does
- Scores job fit against your background (0-100)
- Ranks multiple jobs from best to worst match
- Rewrites your resume bullets for each specific role
- Generates a custom cover letter per job
- Exports both as Word documents ready to send

## Built With
- Python
- Anthropic Claude API
- python-docx

## How To Use
1. Clone this repo
2. Install dependencies: `pip install anthropic python-docx`
3. Set your API key: `export ANTHROPIC_API_KEY=your-key`
4. Paste a job description into `my_agent.py`
5. Run: `python my_agent.py`

## Author
Kelvin Wong, PhD — Genomics Epidemiologist & AI Agent Developer  
[LinkedIn](https://www.linkedin.com/in/kelvin-wong-13775115/)