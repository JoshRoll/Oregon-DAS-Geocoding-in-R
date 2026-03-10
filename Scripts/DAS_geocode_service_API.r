#Author: Josh Roll 
#Date: 10/8/2020
#Description: This script uses DAS's geocoding service API to geocode address data

#Notes:
#Updated 3/9/2026 to consume the latest geocoding service URL and structure

  
	
	#Load libraries
	library(tidyr)
	library(stringr)
	library(dplyr)
	library(httr)
	library(sf)
	library(raster)
	library(jsonlite)
	library(htmlwidgets)
	library(leaflet)
	library(leaflegend)
	library(httr2)
	
	
#Custom functions
#-----------------------------
	#Function that simplifies loading .RData objects
	assignLoad <- function(filename){
		load(filename)
		get(ls()[ls() != "filename"])
	}	
	#Function to mass load files
	massLoadFiles <- function(files) {
		assignLoad(files)		
	}
	#Function to send a batch of addresses for geocoding
	DAS_geocode_Call <- function(Address){
        TempCall <- paste0("https://navigator.state.or.us/arcgis/rest/services/Locators/OregonAddress/GeocodeServer?Street=&City=&State=&ZIP=&SingleLine=+",Address,"&category=&outFields=*&maxLocations=&outSR=&searchExtent=&location=&distance=&magicKey=&f=pjson")
		rest <- GET(TempCall)
		tempExtract <- fromJSON(rawToChar(rest$content), flatten = T)
		dfOut <- data.frame(tempExtract$candidates)    
	}
	
	
	#Write new function to call API
	###################################
	library(httr2)
	library(jsonlite)
	library(dplyr)

	DAS_geocode_Call <- function(address_text,
                             base_url = "https://navigator.state.or.us/arcgis/rest/services/Locators/OregonAddress/GeocodeServer/findAddressCandidates") {
		  
		  out <- tryCatch({			
			resp <- httr2::request(base_url) |>
			  httr2::req_url_query(
				SingleLine = address_text,
				f = "json",
				maxLocations = 1
			  ) |>
			  httr2::req_perform()
			
			dat <- jsonlite::fromJSON(httr2::resp_body_string(resp), simplifyDataFrame = TRUE)
			
			# If no candidates returned
			if (nrow(dat$candidates) == 0) {			  
			  return(data.frame(
				address = "No Address",
				location.x = NA,				
				location.y = NA,
				score = NA,
				extent.xmin = NA,
				extent.ymin = NA,
				extent.xmax = NA,
				extent.ymax = NA,
				stringsAsFactors = FALSE
			  ))
			}
			
			cand <- dat$candidates
			
			if (!is.data.frame(cand)) {
			  cand <- as.data.frame(cand)
			}
			
			cand <- jsonlite::flatten(as.data.frame(dat$candidates))
			rownames(cand) <- NULL
						
			cand
			
		  }, error = function(e) {
			
			# Return fallback record on failure
			data.frame(
				address = "No Address",
				location.x = NA,				
				location.y = NA,
				score = NA,
				extent.xmin = NA,
				extent.ymin = NA,
				extent.xmax = NA,
				extent.ymax = NA,
				stringsAsFactors = FALSE
			)
		  })
		  
		  out
		}
	
	
	

#Define useful script objects
#---------------------------
	#Create a projection file
	Projection <-"+proj=utm +zone=10 +datum=WGS84"
  
	#Define working directory
	setwd("F:/Sandbox/Geocoding")
	
	#Check to see if output and Results directory exists
	if(!(file.exists("Output"))){dir.create("Output")}
	if(!(file.exists("Results"))){dir.create("Results")}
  
  
#--------------------------------------------------------------------------------------------
#Geocode using for loop
#--------------------------------------------------------------------------------------------
	#Load Raw Data to geocode
	Load_Data.. <- read.csv("Data/sample_Address_data.csv")
	#Make a copy of the data
	Data.. <- Load_Data.. 
	#Rename address column - note you will need to use paste0 to concatenate a multipart address field
	Data.. <-  mutate(Data.., Address = Owner_Address)
	#Create an id
	Data..$Id <- 1:nrow(Data..)

	#Develop chunks
	Splits. <- 1:nrow(Data.. )
	#Define Batch (change this for larger batches, i reccomend 10K but did 1K here b/c test data just 2K addresses)
	Batch <- 1000
	#SPlit up data based on batch 
	Chunks_ <- split(Splits., ceiling(seq_along(Splits.)/Batch))
	#Specify Storage path
	Write_Off_Dir <- "Output/"
	
	#Set up progress bar
	#############################
	# Set up progress bar
	pb <- txtProgressBar(min = 1, max = length(Chunks_), style = 3)
	progress <- function(n) setTxtProgressBar(pb, n)

	# Start timer
	Main_Start_Time <- Sys.time()

	for (i in seq_along(Chunks_)) {
	  
	  Start_Time <- Sys.time()
	  
	  # Current chunk of row indices
	  Id <- Chunks_[[i]]
	  
	  # Subset data for this chunk
	  chunk_dat <- Data..[Id, , drop = FALSE]
	  
	  # Keep original row ids
	  chunk_dat$Id <- Data..$Id[Id]
	  
	  # Clean address
	  chunk_dat$Address_clean <- gsub("#", "", chunk_dat$Address)
	  
	  # Keep only valid Oregon records with non-missing address
	  chunk_dat_valid <- chunk_dat %>%
		filter(
		  !is.na(Address_clean),
		  Address_clean != "",
		  !is.na(State),
		  State == "OR"
		)
	  
	  # Initialize output for this chunk
	  Result.. <- data.frame()
	  
	  # Call API only if there are valid records
	  if (nrow(chunk_dat_valid) > 0) {
		
		Api_Call_Result_ <- lapply(chunk_dat_valid$Address_clean, DAS_geocode_Call)
		
		# Keep only non-empty results
		has_rows <- sapply(Api_Call_Result_, nrow) > 0
		
		if (any(has_rows)) {
			Api_Call_Result_ <- Api_Call_Result_[has_rows]

			# Name list elements by source Id
			names(Api_Call_Result_) <- chunk_dat_valid$Id[has_rows]
			# Combine and attach Id
			Result.. <- dplyr::bind_rows(
			lapply(seq_along(Api_Call_Result_), function(j) {
				out <- Api_Call_Result_[[j]]
				out <- as.data.frame(out)
				rownames(out) <- NULL
				out$Id <- names(Api_Call_Result_)[j]
				out
			})
			)
		}
	  }
	  
	  # Save chunk output even if empty
	  save(
		Result..,
		file = paste0(
		  Write_Off_Dir,
		  "Chunk_",
		  min(Id),
		  "_",
		  max(Id),
		  ".RData"
		)
	  )
	  
	  # Update progress
	  progress(i)
	  
	  print(paste0("Chunk ", i, " Done"))
	  print(Sys.time() - Start_Time)
	}

	# Close progress bar
	close(pb)

	# Total elapsed time
	Sys.time() - Main_Start_Time
  
	#Compile the chunks and select only the address points that are based on 
	#######################################
	#Define files to load #Remove master file (if it exists)
	Files_To_Load. <- list.files(Write_Off_Dir)
	#Add file path 
	Files_To_Load. <- paste0(getwd(),"/",Write_Off_Dir,Files_To_Load.)
	#Start timer
	Start_Time <- Sys.time()
	Results.. <- bind_rows(lapply(Files_To_Load., massLoadFiles))
	Sys.time() - Start_Time
	#Save compiled file - not this is all the geocoding results but you need to select only those with attributes.Loc_name equal to a point level (as opposed to zip code)
	save(Results..,file =  paste0("Results/Compiled_Results.RData"))
	
	
#Post processing - start from here if data is extracted
#-----------------------------------------
	#Load results
	Results.. <- assignLoad(file =  paste0("Results/Compiled_Results.RData"))
	#Create a spatial file - remove records with no UTM X coordiante and are not a reliable point 
	Results.. <- 	filter(Results.. ,!is.na( location.x )  ) 
	#Select point with highest score - ignores ties and selects the highest score
	Results.. <- Results..%>% group_by(Id) %>% slice_max(order_by = score, n = 1, with_ties =F) 
	#Join back with original data to measure geocoding success
	Data.. <- left_join(Data.. %>% mutate(Id = as.character(Id)) %>% dplyr::select(c(Id, Owner_Address)), Results..[,c("Id","address","score","location.x","location.y" )], by = "Id")
	#Calculate % of record with no valid geocoded results - for example the results are 89% success, 11% unsuccessful
	table(!is.na(Data..$score )) / nrow(Data..)
	#Examine score 
	table(Data..$attributes.Score < 90)
	table(Data..$attributes.Score > 76)
	
	
	#Spatial data exploration 
	############################################
	#Create a projection file
	Projection_LatLong <- "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"
	Projection_Utm <- "+proj=lcc +lat_1=43 +lat_2=45.5 +lat_0=41.75 +lon_0=-120.5 +x_0=399999.9999984 +y_0=0 +ellps=GRS80 +datum=NAD83 +to_meter=0.3048 +no_defs"
	#Create a spatial data set (spatial objects denoted with _Sp)
	# Create sf point object from X/Y columns
	Data_Sf <- st_as_sf(
		Results..,
		coords = c("location.x", "location.y"),
		crs = Projection_Utm,
		remove = FALSE
	)

	# Transform to lat/long
	Data_Sf <- st_transform(Data_Sf, crs = Projection_LatLong)

	# Write out as a shapefile
	st_write(Data_Sf, "Results/Address.shp", delete_layer = TRUE)

	# Create dynamic leaflet map
	#######################################
	# Create labels
	Data_Sf$label <- with(
	  Data_Sf,
	  paste(
		"<p style='font-size:15px'> <b><i>", "Details", "</i></b> </br>",
		"<b> Address: </b>", address, "</br>",
		"<b> Score: </b>", score, "</br>"
	  )
	)
		 
	#Develop map 
	Map <- leaflet()%>% addTiles() %>%
		addCircles(data = Data_Sf,  fillOpacity = .5,	color = "red",
				 highlightOptions = highlightOptions(color = "white", weight = 2,   bringToFront = TRUE),
			 popup = ~label,
			labelOptions = labelOptions(style = list("font-weight" = "normal", padding = "3px 8px",sticky = T, interactive = T),  textsize = "15px",  direction = "auto")
		) %>%
		addLegend(
			position = "bottomright",
			colors = "red",
			labels = "Geocoded Location",
			title = "Point Type",
			opacity = 1
		)
	Map
	#save to file - savewidget doesnt like relative paths so have to define using getwd()
	saveWidget(Map, file=paste0(getwd(),"/Results/Dynamic_Map.html"), selfcontained = T) 
	


