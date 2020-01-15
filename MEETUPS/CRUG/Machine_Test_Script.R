
library(microbenchmark)

#################
### CPU SPECS
#################

sys_data <- data.frame(user = Sys.info()['user'],
                       os_type = Sys.info()['sysname'],
                       os_release = Sys.info()['release'],
                       os_version = Sys.info()['version'],
                       machine = Sys.info()['machine'],
                       r_version = paste(R.Version()$major, R.Version()$minor, sep="."),
                       r_platform =  R.Version()$platform,
                       r_build_date = paste(R.Version()$year, R.Version()$month, R.Version()$day, sep="-"))


free_data <- data.frame(mem_total = NA, mem_used = NA, mem_free = NA,
                        swap_total = NA, swap_used = NA, swap_free = NA,
                        cpu_cores = NA, cpu_speed = NA)

### LINUX MACHINES
if(Sys.info()[['sysname']] == "Linux") {
  tryCatch({
      free <- system("free", intern=TRUE)
      free[3] <- paste(free[3], " NA NA NA")
  
      free_data <- read.table(text=paste(free, collapse="\n"), header=TRUE)[1:3]
      free_data <- setNames(cbind(free_data["Mem",], free_data["Swap",],  row.names=NULL) / 1E3, 
                        c("mem_total", "mem_used", "mem_free", "swap_total", "swap_used", "swap_free"))
  }, error = function(e) print(e) )

  tryCatch({ free_data$cpu_cores <- system("getconf _NPROCESSORS_ONLN", intern=TRUE) }, 
           error = function(e) print(e) )

  tryCatch({ free_data$cpu_speed <- trimws(strsplit(system("lscpu | grep MHz", intern=TRUE)[1], ":")[[1]][2]) }, 
           error = function(e) print(e) )
}


### MAC OS X MACHINES
if(Sys.info()[['sysname']] == "Darwin") {
  tryCatch({
      txt <- system("top -l 1 | head -n 10", intern=TRUE)
      txt <- txt[grepl("PhysMem", txt)]

      ignore_txt <- strsplit(txt, "([0-9])+G")[[1]]
      for (w in ignore_txt) {txt <- gsub(w, "", txt, fixed = TRUE)}
      vec <- as.numeric(strsplit(txt, "G")[[1]]) * 1000
      free_data <- data.frame(mem_total = sum(vec), mem_used = vec[1], mem_free = vec[2])
  }, error = function(e) print(e) )

  tryCatch({ free_data$cpu_cores <- system("getconf _NPROCESSORS_ONLN", intern=TRUE) }, 
           error = function(e) print(e) )

  tryCatch({ free_data$cpu_speed <- as.numeric(strsplit(system("sysctl hw.cpufrequency", intern=TRUE), ":")[[1]][2]) / 1E6 }, 
           error = function(e) print(e) )
}


### WINDOWS MACHINES
if(Sys.info()[['sysname']] == "Windows") {
  tryCatch({
      free_data <- setNames(cbind(read.table(text=system("wmic ComputerSystem get TotalPhysicalMemory", intern = TRUE),
                                             header=TRUE),
                                  read.table(text=system("wmic OS get FreePhysicalMemory,TotalVirtualMemorySize,FreeVirtualMemory", intern = TRUE),
                                             header=TRUE)),
                            c("mem_total", "mem_free", "swap_free", "swap_total"))
    
      free_data <- within(free_data, {
		        mem_total <- mem_total / 1E6
		        mem_free <- mem_free / 1E3
		        mem_used <- mem_total - mem_free
		        swap_total <- swap_total / 1E3
		        swap_free <- swap_free / 1E3		
		        swap_used <- swap_total - swap_free
      })
			
      free_data <- free_data[c("mem_total", "mem_used", "mem_free", "swap_total", "swap_used", "swap_free")] 
  }, error = function(e) print(e) )
  
  tryCatch({ free_data$cpu_cores <- trimws(system("wmic cpu get NumberOfCores", intern=TRUE))[2] },
           error = function(e) print(e) )

  tryCatch({ free_data$cpu_speed <- trimws(system("wmic cpu get CurrentClockSpeed", intern=TRUE))[2] },
           error = function(e) print(e) )
}

sys_data <- cbind(sys_data, free_data)


machine_run <- function() {
  
  #################
  ### DATA BUILD
  #################
  
  set.seed(2019)
  alpha <- c(LETTERS, letters, c(0:9))
  data_tools <- c("sas", "stata", "spss", "python", "r", "julia")
  
  random_df <- data.frame(
    group = sample(data_tools, 500, replace=TRUE),
    int = sample(1:15, 1E4, replace=TRUE),
    y_num = runif(1E4, 0, 100),
    x_num1 = runif(1E4, 0, 100),
    x_num2 = runif(1E4) * 10,
    x_num3 = rnorm(1E4, 10),
    x_num4 = rnorm(1E4, 50),
    x_num5 = rnorm(1E4, 100),
    char = replicate(1E4, paste(sample(alpha, 3, replace=TRUE), collapse="")),
    bool = sample(c(TRUE, FALSE), 1E4, replace=TRUE),
    date = as.Date(sample(as.integer(as.Date("2000-01-01")):as.integer(Sys.Date()), 
                          1E4, replace=TRUE), origin="1970-01-01")
  )

  #################
  ### AGGREGATION
  #################
  
  agg_df <- do.call(data.frame, 
                    aggregate(cbind(y_num, x_num1, x_num2, x_num3, x_num4, x_num5) ~ group, random_df, 
                              FUN=function(x) c(sum=sum(x), 
                                                mean=mean(x),
                                                median=median(x),
                                                min=min(x),
                                                max=max(x)))
  )
  
  agg_df <- cbind(agg_df[c(1, grep("sum", names(agg_df)))],
                  agg_df[grep("mean", names(agg_df))],
                  agg_df[grep("median", names(agg_df))],
                  agg_df[grep("min", names(agg_df))],
                  agg_df[grep("max", names(agg_df))])
  
  agg_df 
  
  
  #################
  ### PLOT
  #################
  
  seaborn_palette <- c('#4878d0', '#ee854a', '#6acc64', '#d65f5f', '#956cb4', '#8c613c', 
                       '#dc7ec0', '#797979', '#d5bb67', '#82c6e2', '#4878d0', '#ee854a', 
                       '#6acc64', '#d65f5f', '#956cb4', '#8c613c', '#dc7ec0', '#797979', 
                       '#d5bb67', '#82c6e2', '#4878d0', '#ee854a', '#6acc64', '#d65f5f')
  
  # HISTOGRAM BY GROUP
  pdf(NULL)
  hist(subset(random_df, random_df$group == "julia")$y_num, 
       col=rgb(0,0,1,0.25), breaks=50, ylim=c(0, 5000),
       main="Overlapping Histogram", xlab="y_num")
  hist(subset(random_df, random_df$group == "r")$y_num, col=rgb(0,0,1,0.5), breaks=50, add=TRUE)
  hist(subset(random_df, random_df$group == "python")$y_num, col=rgb(0,0,1,0.75), breaks=50, add=TRUE)
  hist(subset(random_df, random_df$group == "sas")$y_num, col=rgb(1,0,0,0.5), breaks=50, add=TRUE)
  hist(subset(random_df, random_df$group == "stata")$y_num, col=rgb(1,0,0,0.75), breaks=50, add=TRUE)
  hist(subset(random_df, random_df$group == "spss")$y_num, col=rgb(1,0,0,0.75), breaks=50, add=TRUE)
  
  legend("top", c("julia", "r", "python", "sas", "stata", "spss"), ncol=6,
         fill=c(rgb(0,0,1,0.25), rgb(0,0,1,0.5), rgb(0,0,1,0.75),
                rgb(1,0,0,0.25), rgb(1,0,0,0.5), rgb(1,0,0,0.75)))
  box()
  dev.off()

  # BAR PLOT BY GROUP AND YEAR
  random_df$year <- format(random_df$date, "%Y")
  graph_data <- tapply(random_df$y_num, list(random_df$group, random_df$year), mean)
  pdf(NULL)
  barplot(graph_data, beside=TRUE, col=seaborn_palette[1:6], legend=NULL, 
          ylim=range(pretty(c(0, graph_data))),
          main="Barplot by Group and Year", ylab="y_num")
  
  legend("top", row.names(graph_data), ncol=6, fill=seaborn_palette[1:6])
  box()
  dev.off()
  
  #################
  ### MODEL RUN
  #################
  
  expvar_list <- lapply(1:5, function(x) combn(paste0("x_num", 1:5), x, simplify=FALSE))
  
  formulas_list <- rapply(expvar_list, function(x) paste(paste("y_num ~", paste(x, collapse=" + ")), " + group"))
  formulas_list
  
  models <- lapply(formulas_list, function(m) lm(m, data=random_df))
  
  #################
  ### RESULTS
  #################
  
  coeff_matrices <- vector(mode="list", length = length(models))
  rf_matrices <- vector(mode="list", length = length(models))
  anova_dfs <- vector(mode="list", length = length(models))
  plot_results  <- vector(mode="list", length = length(models))
  
  build_plot <-  function(i){
    pdf(NULL)
    dev.control(displaylist="enable")
    barplot(coeff_matrices[[i]][,1], col=seaborn_palette[1:nrow(coeff_matrices[[i]])],
            legend = row.names(coeff_matrices[[i]]), ylim=c(-10, 60),
            main=paste0("Model - ", i))
    box()
    
    p <- recordPlot()
    invisible(dev.off())
    return(p)
  }
  
  for(i in seq_along(models)){
    res <- summary(models[[i]])
    
    coeff_matrices[[i]] <- res$coefficients
    
    p <- res$fstatistic
    rf_matrices[[i]] <- c(r_sq = res$r.squared,
                          adj_r_sq = res$adj.r.squared,
                          f_stat = p[['value']],
                          p_value = unname(pf(p[1], p[2], p[3], lower.tail=FALSE))
    )
    
    anova_dfs[[i]] <- anova(models[[i]])
    
    plot_results[[i]] <- build_plot(i)
  }
}

#####################
### RUNTIME MEMORY
#####################

machine_run()
mem_stats <- gc()
colnames(mem_stats) <- c("used", "used_mb", "gc_trigger", "gc_trigger_mb", "max_used", "max_used_mb")
mem_stats <- colSums(mem_stats)

sys_data <- within(sys_data, { 
                use_mb <- mem_stats['used_mb']
                gc_trigger_mb <- mem_stats['gc_trigger_mb']
                max_used_mb <- mem_stats['max_used_mb']
            })


#####################
### BENCHMARK
#####################

mb_stats <- do.call(data.frame, aggregate(time~., microbenchmark(machine_run(), times=5L, unit="s"), function(x)
  c(min = min(x) / 1E9,
    lq = unname(quantile(x)[2]) / 1E9,
    mean = mean(x) / 1E9,
    median = median(x) / 1E9,
    uq = unname(quantile(x)[4]) / 1E9,
    max = max(x) / 1E9,
    neval = 5L)
))


sys_data <- cbind(sys_data, mb_stats, row.names=NULL)

# OUTPUT TO SCREEN
print(sys_data)

# OUTPUT TO FILE
write.csv(sys_data, "Machine_Test_Results_r.csv", row.names=FALSE)
