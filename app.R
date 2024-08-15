library(shiny)
library(tools)
library(stringr)

author = "shitao5"

add_yaml <- function(file, title, author, date, format) {
  # 定义基础的 YAML 内容
  basic_yaml <- paste0(
    "---\n",
    "title: \"", title, "\"\n",
    "author: \"", author, "\"\n",
    "date: \"", date, "\"\n",
    "date-format: iso\n",
    "include-in-header:\n",
    "    - text: |\n",
    "       <script src=\"pangu.min.js\"></script>\n",
    "       <script>\n",
    "         document.addEventListener('DOMContentLoaded', function() {\n",
    "           pangu.spacingPage();\n",
    "        });\n",
    "       </script>\n"
  )
  
  # 根据 format 添加特定内容
  if (tolower(format) == "html") {
    yaml_content <- paste0(
      basic_yaml,
      "format:\n",
      "  html:\n",
      "    toc: true\n",
      "    toc-location: left\n",
      "    number-sections: true\n",
      "    embed-resources: true\n",
      "    link-external-newwindow: true\n",
      "---\n\n"
    )
  } else if (tolower(format) == "docx") {
    yaml_content <- paste0(
      basic_yaml,
      "format:\n",
      "  docx:\n",
      "    number-sections: true\n",
      "---\n\n"
    )
  } else {
    stop("Unsupported format. Please choose 'html' or 'word'.")
  }
  
  c(yaml_content, file)
}

# 定义 Shiny 服务器逻辑
server <- function(input, output, session) {
  # 处理上传的文件
  file_data <- reactive({
    inFile <- input$file
    if (is.null(inFile))
      return(NULL)
    readLines(inFile$datapath)
  })
  
  # 监听按钮点击事件，进行处理和渲染
  output$download <- downloadHandler(
    filename = function() {
      paste0(tools::file_path_sans_ext(input$file$name), ifelse(input$format == "html", ".html", ".docx"))
    },
    content = function(file) {
      req(file_data())
      test_clean <- str_replace(file_data(), "^\\- (#+ )", "\\1")
      test_clean <- test_clean[!grepl("background-color::", test_clean)]
      test_clean <- test_clean[!grepl("id::", test_clean)]
      bind_lines <- c(rbind(test_clean, ""))
      
      res <- add_yaml(bind_lines,
                      title = ifelse(input$title == "", tools::file_path_sans_ext(input$file$name), input$title),
                      author = input$author,
                      date = input$date,
                      format = input$format)
      
      # 写入到临时文件
      temp_qmd <- tempfile(fileext = ".qmd")
      temp_dir = dirname(temp_qmd)
      writeLines(res, temp_qmd)
      file.copy("pangu.min.js", temp_dir)
      
      # 设置输出格式和文件名
      output_format <- ifelse(input$format == "html", "html", "docx")
      output_file_name <- paste0(temp_dir, "/",
                                 tools::file_path_sans_ext(basename(temp_qmd)), ".", output_format)
      
      # 调用系统命令执行 Quarto 渲染
      cmd <- paste("quarto render", shQuote(temp_qmd))
      system(cmd)
      
      # 将渲染完成的文件复制到 Shiny 输出文件位置
      file.copy(output_file_name, file, overwrite = TRUE)
      
      # 删除临时文件
      unlink(c(temp_qmd, output_file_name))
    }
    
  )
}

# 定义 Shiny 用户界面
ui <- fluidPage(
  titlePanel("Logseq 文件美化导出"),
  sidebarLayout(
    sidebarPanel(
      fileInput("file", "上传 Logseq 的 md 文件", accept = ".md"),
      textInput("title", "标题", value = "", placeholder = "默认为文件名"),
      textInput("author", "作者", value = author),
      dateInput("date", "日期", value = Sys.Date()),
      selectInput("format", "输出格式", choices = c("html", "docx")),
      downloadButton("download", "渲染并下载")
    ),
    mainPanel(
      textOutput("status")
    )
  )
)

# 运行 Shiny 应用
shinyApp(ui = ui, server = server)
