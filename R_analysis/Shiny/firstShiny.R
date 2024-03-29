## https://mastering-shiny.org/basic-app.html

library("shiny")

ui <- fluidPage(
  selectInput("dataset", label = "Dataset", choices = ls("package:datasets")),
  verbatimTextOutput("summary"),
  tableOutput("table")
)

## fluidPage() is a layout function that sets up the basic visual structure of the page.
## selectInput() is an input control for user interaction with the app by providing a value.
## In this case, it’s a select box with the label “Dataset” and lets you choose one of the built-in datasets that come with R.
## verbatimTextOutput() and tableOutput() are output controls that tell Shiny where to put rendered output (we’ll get into the how in a moment).
## verbatimTextOutput() displays code and tableOutput() displays tables.

server <- function(input, output, session) {
  # Create a reactive expression. To be called later like a function
  dataset <- reactive({
    get(input$dataset, "package:datasets")
  })
  
  output$summary <- renderPrint({
    # Use a reactive expression by calling it like a function
    summary(dataset())
  })
  
  output$table <- renderTable({
    dataset()
  })
}

shinyApp(ui, server)


