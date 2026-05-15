library(shiny)
library(httr)
library(jsonlite)
library(officer)

# ============================================
# KELVIN'S BACKGROUND
# ============================================
KELVIN_CV <- "
- PhD in Environmental Engineering, Michigan State University
- Genomics Epidemiologist at California Department of Public Health (CDPH), 2022-present
- 15+ years in wastewater surveillance, genomics, molecular biology
- Built R Shiny dashboards for California COVID wastewater surveillance (80+ sites)
- Python (Pandas, NumPy, Scikit-Learn), R, SQL, bash, Git
- Machine learning: Random Forest, clustering, PCA, time series, anomaly detection
- NGS, metagenomics, qPCR, library prep, bioinformatics pipelines
- EPA Level 1 Science Award, 20+ publications, ~1000 citations
- Currently building AI agents using Claude API and Claude Code
"

# ============================================
# CALL CLAUDE API FROM R
# ============================================
call_claude <- function(system_prompt, user_prompt, max_tokens = 2000) {
  response <- POST(
    "https://api.anthropic.com/v1/messages",
    add_headers(
      "x-api-key"         = Sys.getenv("ANTHROPIC_API_KEY"),
      "anthropic-version" = "2023-06-01",
      "Content-Type"      = "application/json"
    ),
    body = toJSON(list(
      model      = "claude-sonnet-4-5",
      max_tokens = max_tokens,
      system     = system_prompt,
      messages   = list(
        list(role = "user", content = user_prompt)
      )
    ), auto_unbox = TRUE),
    encode = "raw"
  )
  content(response)$content[[1]]$text
}

# ============================================
# UI
# ============================================
ui <- fluidPage(
  
  # Styling
  tags$head(tags$style(HTML("
    body { background-color: #0a0a0f; color: #e8e8f0; font-family: 'DM Mono', monospace; }
    .title-box { background: linear-gradient(135deg, #00C9A7, #4D96FF);
                 -webkit-background-clip: text; -webkit-text-fill-color: transparent;
                 font-size: 32px; font-weight: 800; margin-bottom: 5px; }
    .subtitle  { color: #888; font-size: 13px; margin-bottom: 30px; }
    .card      { background: #0f0f1a; border: 1px solid #1e1e2e;
                 border-radius: 12px; padding: 20px; margin-bottom: 20px; }
    .card-title { color: #00C9A7; font-size: 11px; letter-spacing: 3px;
                  margin-bottom: 12px; font-weight: 600; }
    .score-box { text-align: center; padding: 20px;
                 background: #080810; border-radius: 10px; }
    .score-num { font-size: 64px; font-weight: 800; line-height: 1; }
    .score-label { font-size: 12px; color: #888; margin-top: 5px; }
    .recommend { font-size: 18px; font-weight: 700; margin-top: 10px; }
    .reason-box { background: #080810; border-left: 3px solid #4D96FF;
                  padding: 12px 16px; border-radius: 0 8px 8px 0;
                  font-size: 13px; color: #aaa; line-height: 1.6; }
    .skill-tag { display: inline-block; background: #1a1a28;
                 border: 1px solid #2a2a3a; border-radius: 20px;
                 padding: 4px 12px; font-size: 11px; color: #888;
                 margin: 3px; }
    .gap-tag   { display: inline-block; background: #2a1a1a;
                 border: 1px solid #3a2a2a; border-radius: 20px;
                 padding: 4px 12px; font-size: 11px; color: #ff6b6b;
                 margin: 3px; }
    textarea   { background: #080810 !important; color: #e8e8f0 !important;
                 border: 1px solid #1e1e2e !important; border-radius: 8px !important; }
    .btn-run   { background: linear-gradient(135deg, #00C9A7, #0088cc);
                 color: white; border: none; border-radius: 10px;
                 padding: 12px 30px; font-size: 14px; font-weight: 600;
                 width: 100%; margin-top: 10px; cursor: pointer; }
    .btn-run:hover { filter: brightness(1.1); color: white; }
    .btn-dl    { background: #1a1a28; color: #888; border: 1px solid #2a2a3a;
                 border-radius: 8px; padding: 10px 20px; width: 100%;
                 margin-top: 8px; }
    .btn-dl:hover { border-color: #00C9A7; color: #00C9A7; }
    .progress-wrap { background: #1e1e2e; border-radius: 4px;
                     height: 8px; margin-top: 10px; overflow: hidden; }
    .progress-fill { height: 100%; border-radius: 4px;
                     background: linear-gradient(90deg, #00C9A7, #4D96FF);
                     transition: width 0.8s ease; }
  "))),
  
  # Header
  div(style = "max-width: 900px; margin: 40px auto; padding: 0 20px;",
      
      div(class = "title-box", "🤖 Kelvin's Job Search Agent"),
      div(class = "subtitle",
          "Paste a job description → get instant fit analysis + tailored resume + cover letter"),
      
      fluidRow(
        
        # LEFT — Input
        column(5,
               div(class = "card",
                   div(class = "card-title", "JOB DETAILS"),
                   textInput("job_title", "Job Title",
                             placeholder = "e.g. Senior Data Scientist - CDC"),
                   textAreaInput("job_desc", "Job Description",
                                 placeholder = "Paste the full job description here...",
                                 rows = 10),
                   actionButton("analyze", "▶  Analyze Job",
                                class = "btn-run")
               )
        ),
        
        # RIGHT — Output
        column(7,
               
               # Score card
               div(class = "card",
                   div(class = "card-title", "FIT ANALYSIS"),
                   uiOutput("score_ui")
               ),
               
               # Downloads
               div(class = "card",
                   div(class = "card-title", "DOCUMENTS"),
                   uiOutput("download_ui")
               )
        )
      )
  )
)

# ============================================
# SERVER
# ============================================
server <- function(input, output, session) {
  
  # Store results reactively
  analysis   <- reactiveVal(NULL)
  resume_data <- reactiveVal(NULL)
  cover_data  <- reactiveVal(NULL)
  
  # ── Analyze button ──
  observeEvent(input$analyze, {
    
    req(input$job_title, input$job_desc)
    
    # Reset
    analysis(NULL)
    resume_data(NULL)
    cover_data(NULL)
    
    withProgress(message = "🤖 Analyzing job fit...", value = 0, {
      
      # Step 1 — Score
      setProgress(0.2, detail = "Scoring job fit...")
      raw <- call_claude(
        system_prompt = "You are a job fit analyzer. Respond ONLY with valid JSON. No markdown.",
        user_prompt   = paste0(
          "Analyze this job for Kelvin:\n",
          "BACKGROUND: ", KELVIN_CV, "\n",
          "JOB: ", input$job_title, "\n",
          "REQUIREMENTS: ", input$job_desc, "\n\n",
          "Return JSON with:\n",
          "- fit_score (0-100)\n",
          "- apply_recommendation (YES/MAYBE/NO)\n",
          "- top_matching_skills (list of 4)\n",
          "- gaps (list, empty if none)\n",
          "- one_line_reason (string)"
        )
      )
      clean <- gsub("```json|```", "", raw)
      result <- fromJSON(clean)
      analysis(result)
      
      # Step 2 — Resume content
      setProgress(0.5, detail = "Tailoring resume...")
      raw2 <- call_claude(
        system_prompt = "You are an expert resume writer. Respond ONLY with valid JSON. No markdown.",
        user_prompt   = paste0(
          "Create tailored resume for Kelvin for: ", input$job_title, "\n",
          "Job requirements: ", input$job_desc, "\n",
          "Background: ", KELVIN_CV, "\n\n",
          "Return JSON with:\n",
          "- summary (2 punchy sentences)\n",
          "- skills (list of 8)\n",
          "- experience (list of 4, each: title, company, dates, bullets (list of 2))\n",
          "- education (list of 3, each: degree, school, year)\n",
          "- awards (list of 2)"
        )
      )
      clean2 <- gsub("```json|```", "", raw2)
      resume_data(fromJSON(clean2))
      
      # Step 3 — Cover letter
      setProgress(0.8, detail = "Writing cover letter...")
      raw3 <- call_claude(
        system_prompt = "You are an expert cover letter writer.",
        user_prompt   = paste0(
          "Write a professional 3-paragraph cover letter for Kelvin applying to: ",
          input$job_title, "\n",
          "Job: ", input$job_desc, "\n",
          "Background: ", KELVIN_CV, "\n\n",
          "Paragraph 1: Hook + why this role\n",
          "Paragraph 2: Top 2 specific achievements\n",
          "Paragraph 3: Forward-looking close\n",
          "Under 250 words. No placeholders."
        )
      )
      cover_data(raw3)
      setProgress(1, detail = "Done!")
    })
  })
  
  # ── Score UI ──
  output$score_ui <- renderUI({
    if (is.null(analysis())) {
      return(div(style = "color: #444; text-align: center; padding: 40px;",
                 "← Paste a job and click Analyze"))
    }
    
    r <- analysis()
    score <- as.numeric(r$fit_score)
    color <- if (score >= 80) "#00C9A7" else if (score >= 60) "#ffbd2e" else "#ff6b6b"
    rec_color <- switch(r$apply_recommendation,
                        "YES"   = "#00C9A7",
                        "MAYBE" = "#ffbd2e",
                        "NO"    = "#ff6b6b")
    
    tagList(
      fluidRow(
        column(5,
               div(class = "score-box",
                   div(class = "score-num", style = paste0("color:", color), score),
                   div(class = "score-label", "FIT SCORE / 100"),
                   div(class = "progress-wrap",
                       div(class = "progress-fill",
                           style = paste0("width:", score, "%; background:", color))),
                   div(class = "recommend",
                       style = paste0("color:", rec_color),
                       r$apply_recommendation)
               )
        ),
        column(7,
               div(class = "reason-box", r$one_line_reason),
               br(),
               div(class = "card-title", style="margin-top:10px", "MATCHING SKILLS"),
               div(lapply(r$top_matching_skills, function(s)
                 span(class = "skill-tag", s))),
               if (length(r$gaps) > 0) {
                 tagList(
                   div(class = "card-title", style="margin-top:10px", "GAPS"),
                   div(lapply(r$gaps, function(g) span(class = "gap-tag", g)))
                 )
               }
        )
      )
    )
  })
  
  # ── Download UI ──
  output$download_ui <- renderUI({
    if (is.null(resume_data())) {
      return(div(style = "color: #444; text-align: center; padding: 20px;",
                 "Documents will appear here after analysis"))
    }
    tagList(
      downloadButton("dl_resume", "📄  Download Tailored Resume (.docx)",
                     class = "btn-dl"),
      downloadButton("dl_cover", "✉️   Download Cover Letter (.docx)",
                     class = "btn-dl")
    )
  })
  
  # ── Download Resume ──
  output$dl_resume <- downloadHandler(
    filename = function() paste0("resume_", gsub(" ", "_", input$job_title), ".docx"),
    content  = function(file) {
      r <- resume_data()
      doc <- read_docx()
      
      # Name header
      doc <- doc %>%
        body_add_par("KELVIN WONG, PhD", style = "heading 1") %>%
        body_add_par("Pittsburg, CA  |  510-605-8602  |  kelvinmsu@outlook.com", style = "Normal") %>%
        body_add_par("", style = "Normal") %>%
        
        # Summary
        body_add_par("PROFESSIONAL SUMMARY", style = "heading 2") %>%
        body_add_par(r$summary, style = "Normal") %>%
        body_add_par("", style = "Normal") %>%
        
        # Skills
        body_add_par("TECHNICAL SKILLS", style = "heading 2") %>%
        body_add_par(paste(r$skills, collapse = "  •  "), style = "Normal") %>%
        body_add_par("", style = "Normal") %>%
        
        # Experience
        body_add_par("PROFESSIONAL EXPERIENCE", style = "heading 2")
      
      for (job in r$experience) {
        doc <- doc %>%
          body_add_par(paste0(job$title, "  —  ", job$company, "  |  ", job$dates),
                       style = "Normal") %>%
          body_add_par(paste0("• ", job$bullets[[1]]), style = "Normal") %>%
          body_add_par(paste0("• ", job$bullets[[2]]), style = "Normal") %>%
          body_add_par("", style = "Normal")
      }
      
      # Education
      doc <- doc %>%
        body_add_par("EDUCATION", style = "heading 2")
      for (edu in r$education) {
        doc <- doc %>%
          body_add_par(paste0(edu$degree, "  —  ", edu$school, ", ", edu$year),
                       style = "Normal")
      }
      
      # Awards
      doc <- doc %>%
        body_add_par("", style = "Normal") %>%
        body_add_par("HONORS & AWARDS", style = "heading 2")
      for (award in r$awards) {
        doc <- doc %>% body_add_par(paste0("• ", award), style = "Normal")
      }
      
      print(doc, target = file)
    }
  )
  
  # ── Download Cover Letter ──
  output$dl_cover <- downloadHandler(
    filename = function() paste0("cover_letter_", gsub(" ", "_", input$job_title), ".docx"),
    content  = function(file) {
      doc <- read_docx() %>%
        body_add_par("Kelvin Wong, PhD", style = "heading 1") %>%
        body_add_par("Pittsburg, CA  |  510-605-8602  |  kelvinmsu@outlook.com",
                     style = "Normal") %>%
        body_add_par("", style = "Normal") %>%
        body_add_par(paste0("Re: ", input$job_title), style = "heading 2") %>%
        body_add_par("", style = "Normal")
      
      for (para in strsplit(cover_data(), "\n\n")[[1]]) {
        if (nchar(trimws(para)) > 0) {
          doc <- doc %>% body_add_par(trimws(para), style = "Normal") %>%
            body_add_par("", style = "Normal")
        }
      }
      
      doc <- doc %>%
        body_add_par("Sincerely,", style = "Normal") %>%
        body_add_par("", style = "Normal") %>%
        body_add_par("Kelvin Wong, PhD", style = "Normal")
      
      print(doc, target = file)
    }
  )
}

# ============================================
# RUN
# ============================================
shinyApp(ui = ui, server = server)