library("shiny")
library("tidyverse")
library("phyloseq")
library("BiocManager")
library("DT")
options(repos = BiocManager::repositories())

num.decimals <- function(x) {
  stopifnot(class(x)=="numeric")
  x <- sub("0+$","",x)
  x <- sub("^.+[.]","",x)
  nchar(x)
}


function(input, output, session) {
  
  ps <- reactive({
    
    file <- input$file1
    ext <- tools::file_ext(file$datapath)
    
    req(file)
    validate(need(ext == c("rds","RDS"), "Please upload a rds file"))
    
    readRDS(file$datapath)
    
  })
  
  output$inPs <- renderPrint({
    
    if (!is.null(ps())){
      
      ## Filter Controls from pipeline 
      if("Sample_or_Control" %in% colnames(sample_data(ps()))) {
        
        fltps.noContrl <- reactive({
          ## Filter out controls
          subset_samples(ps(), Sample_or_Control != "Control")
          
        })
        
      } else {
        
        fltps.noContrl <- reactive(ps())
      
      }
      
      ## Compute number of sample for each ASV, store as data.frame
      abunfltdf <- reactive({
        
        apply(X = otu_table(fltps.noContrl()),
              MARGIN = ifelse(taxa_are_rows(fltps.noContrl()), yes = 1, no = 2),
              FUN = function(x){sum(x > 0)})
        
      }) 
      
      ## Add taxonomy and total read counts to this data.frame
      abunfltdata <- reactive({
        
        data.frame(Prevalence = abunfltdf(),
                   TotalAbundance = taxa_sums(fltps.noContrl()),
                   tax_table(fltps.noContrl())[, input$taxaLevel])
      })
      
      totalReads <- reactive({sum(abunfltdata()$TotalAbundance)})
      
      output$summary <- renderText(
        
        paste0("The input file has ", nsamples(fltps.noContrl()), " samples, with ", totalReads(), " reads, across ", ntaxa(fltps.noContrl()), " ASVs")
        
      )
      
      output$taxaFilter <- renderPlot({
        
        ggplot(abunfltdata(), aes(TotalAbundance, Prevalence / nsamples(fltps.noContrl()),color=get(input$taxaLevel))) +
          geom_hline(yintercept = input$prevaTaxa/100, alpha = 1, linetype = 2) +
          geom_vline(xintercept = input$abunTaxa * totalReads() / 100, alpha = 1, linetype = 3) +
          geom_point(size = input$pointSize, alpha = input$pointTrans) +
          scale_x_log10() +  xlab("Total Abundance") + ylab("Prevalence [Frac. Samples]") +
          facet_wrap(~get(input$taxaLevel), ncol = 2) + theme(legend.position="none")
        ## input$taxaLevel is a constant characters string, so need to have get.
        
      })
      
      prevaContamFreeTable <- reactive(
        
        abunfltdata() %>% rownames_to_column("ASVs") %>% 
          mutate(Prevalence_percentage = Prevalence/nsamples(fltps.noContrl()) * 100, Abundance_percentage = TotalAbundance/totalReads()*100) %>%
          select(ASVs,input$taxaLevel,Prevalence,Prevalence_percentage,TotalAbundance,Abundance_percentage) %>%
          filter(Prevalence_percentage >= input$prevaTaxa & Abundance_percentage >= input$abunTaxa)
      )
      
      output$filterSummary <- renderText(
        
        paste0("ASVs with number of reads below ", ceiling(input$abunTaxa * totalReads() / 100), " (", input$abunTaxa, " %) and appeared in less than " , ceiling(input$prevaTaxa * nsamples(fltps.noContrl()) / 100), " samples (", input$prevaTaxa, " %)  were filtered out. There are ", nrow(prevaContamFreeTable ()), " ASVs left (", round((ntaxa(fltps.noContrl()) - nrow(prevaContamFreeTable ())) / ntaxa(fltps.noContrl()) *100, digits = 2), " % was removed)." )
        
      )
      
      deciPlace <- reactive({
        num.decimals(input$abunTaxa)
      })

      output$taxaTable <- DT::renderDataTable({
        
        DT::datatable(prevaContamFreeTable(), options = list(orderClasses = TRUE)) %>%
          formatRound(columns='Prevalence_percentage', 2) %>%
          formatRound(column ='Abundance_percentage', deciPlace())
      
      })
      
      if (input$excludeTaxa==""){
        
        saveData <- reactive ({
          
          keeptaxa <- prevaContamFreeTable()$ASVs
          prune_taxa(keeptaxa, fltps.noContrl())
          
        })
        
      } else {
        
        saveDataTax <- reactive({
          
          removeTaxa <- reactive({
            
            prevaContamFreeTable() %>% filter(!grepl(input$excludeTaxa, get(input$taxaLevel))) %>% select(ASVs)
          
          })
          
          keepTaxa <- removeTaxa()$ASVs
          
          prune_taxa(keepTaxa, fltps.noContrl())
          
        })
        

        output$test <- renderPrint(
          
          saveDataTax()
                            
        )
        
      }

      # Download csv abundance table
      output$downloadTable <- downloadHandler(
        
        filename = function() {
          
          paste(input$name, "table.csv", sep = "_")
          
        },
        
        content = function(file) {
          
          write.csv(prevaContamFreeTable(), file)
          
        }
      )
      
      # Download filtered files
      output$downloadData <- downloadHandler(
        
        filename = function() {
          
          paste(input$name, "filtered.rds", sep = "_")
          
        },
        content = function(file) {
          
          saveRDS(saveData(), file)
          
        }
      )
    }
    
  })
  
}