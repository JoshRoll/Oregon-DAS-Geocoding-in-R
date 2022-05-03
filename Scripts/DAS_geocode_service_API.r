#Author: Josh Roll 
#Date: 10/8/2020
#Description: This script uses DAS's geocoding service API to geocode address data

#Notes:

  
	#Ensure proper directory for libraries
	.libPaths("C:/Program Files/R/R-4.0.2/library")
	#Load libraries
	library(tidyr)
	library(stringr)
	library(dplyr)
	library(httr)
	library(sp)
	library(raster)
	library(jsonlite)
	library(htmlwidgets)
	library(leaflet)
	library(leaflegend)
	
	
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
        TempCall <- paste0("https://navigator.state.or.us/arcgis/rest/services/Locators/gc_Composite/GeocodeServer/findAddressCandidates?Street=&City=&State=&ZIP=&SingleLine=+",Address,"&category=&outFields=*&maxLocations=&outSR=&searchExtent=&location=&distance=&magicKey=&f=pjson")
		rest <- GET(TempCall)
		tempExtract <- fromJSON(rawToChar(rest$content), flatten = T)
		dfOut <- data.frame(tempExtract$candidates)    
	}

#Define useful script objects
#---------------------------
	#Create a projection file
	Projection <-"+proj=utm +zone=10 +datum=WGS84"
  
	#Define working directory
	setwd("//wpdotfill09/R_VMP3_USERS/tdb069/Sandbox/Geocoding")
	
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
	Data.. <-  mutate(Data..,Address = Owner_Address)
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
	pb <- txtProgressBar(min=1, max=length(Chunks_), style=3)
	progress <- function(n) setTxtProgressBar(pb, n)
	opts <- list(progress=progress)
	#Start a timer
	Main_Start_Time <- Sys.time()
	#Init process
	for(i in 1:length(Chunks_)){
		Start_Time <- Sys.time()
		#Create Id
		Id <-  Chunks_[[i]]
		#Determine Premise IF
		Record_Id <- Data..$Id[Id]
		#Develop query 
		Address <- gsub(" ","+",Data..$Address[Id])
		#Remove pound signs
		Address <- gsub("#","",Address)
		State <- Data..$State[Id]
		#Check to make sure address is present - to ensure all fields spec outFields as outFields=*
		if(all(!(is.na(Address)) & State%in%"OR")){
			#Batch call 
			Api_Call_Result_ <- lapply(  Address, DAS_geocode_Call)
		}
		#Check to make sure there are results
		if(length(Api_Call_Result_)>0){
		  #Name the list to maintain the Ids
		  names(Api_Call_Result_) <- Id
		  #Convert to data frame and append Ids
		  Result.. <- cbind(do.call("rbind",Api_Call_Result_), Id = rep(names(Api_Call_Result_), sapply(Api_Call_Result_, nrow)))
		}
		#Write out results to avoid problems with Geocoder not finishing 
		save(Result.., file = paste(Write_Off_Dir, "Chunk_",min(Id),"_",max(Id),".RData",sep=""))
		#Print progress 
		print(paste0("Chunk ",i," Done"))
		print(Sys.time() - Start_Time)		  
	#Close for loop
	}
    #Record end time
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
	Results.. <- 	filter(Results.. ,!is.na(attributes.X) & attributes.Loc_name%in%c("ADDRESSPOINT","NAVTEQ","ORTRANS") ) 
	#Select point with highest score - ignores ties and selects the highest score
	Results.. <- Results..%>% group_by(Id) %>% slice_max(order_by = attributes.Score, n = 1, with_ties =F) 
	#Join back with original data to measure geocoding success
	Data.. <- left_join(Data.. %>% mutate(Id = as.character(Id)), Results..[,c("Id","address","attributes.Loc_name","attributes.Score","location.x","location.y","attributes.DisplayX","attributes.DisplayY" )], by = "Id")
	#Calculate % of record with no valid geocoded results - for example the results are 89% success, 11% unsuccessful
	table(!is.na(Data..$attributes.Score )) / nrow(Data..)
	#Examine score 
	table(Data..$attributes.Score < 90)
	table(Data..$attributes.Score > 76)
	
	
	#Spatial data exploration 
	############################################
	#Create a projection file
	Projection_LatLong <- "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"
	Projection_Utm <- "+proj=lcc +lat_1=43 +lat_2=45.5 +lat_0=41.75 +lon_0=-120.5 +x_0=399999.9999984 +y_0=0 +ellps=GRS80 +datum=NAD83 +to_meter=0.3048 +no_defs"
	#Create a spatial data set (spatial objects denoted with _Sp)
	Data_Sp <- SpatialPointsDataFrame(Results..[,c("attributes.X","attributes.Y")], proj4string = CRS(Projection_Utm), data = 	Results.. )
	
	#Transform
	Data_Sp <- spTransform(	Data_Sp, CRS(Projection_LatLong))
	
	#Write out as a spatial file 
	shapefile(Data_Sp, paste0("Results/Address"), overwrite=TRUE)
	
	#Create dynamic leaflet map
	
	#Create color pallette
	Colors. <-  colorRampPalette(c("red","skyblue", "purple"))(3)
	mypal <- colorFactor(Colors., domain = unique(Data_Sp@data$attributes.Loc_name))
	#Create labels
	Data_Sp@data$label <- with(Data_Sp@data, paste(
		#Pedestrian Injury
		"<p style='font-size:15px'> <b><i>", "Details", "</i></b> </br>",
		"<b> Address: </b>",Data_Sp@data$address, "</br>",
		"<b> Score: </b>", Data_Sp@data$attributes.Score, "</br>",
		"<b> Geocode Location Type: </b>", Data_Sp@data$attributes.Loc_name , "</br>"))
		 
	#Develop map 
	Map <- leaflet(Data_Sp)%>% addTiles() %>%
		addCircles(data=Data_Sp,  fillOpacity = .5,	color = ~mypal(attributes.Loc_name),
				 highlightOptions = highlightOptions(color = "white", weight = 2,   bringToFront = TRUE),
			 popup = ~label,
			labelOptions = labelOptions(style = list("font-weight" = "normal", padding = "3px 8px",sticky = T,interactive = T),  textsize = "15px",  direction = "auto")
		) %>%
	  addLegendFactor(position = "bottomright",  pal = mypal, values = Data_Sp@data$attributes.Loc_name,title = htmltools::tags$div("DAS Gecoding Service Results", style = "font-size: 24px; color: black;"),
	  opacity = 1, width = 50, height = 50)	
	Map
	#save to file - savewidget doesnt like relative paths so have to define using getwd()
	saveWidget(Map, file=paste0(getwd(),"/Results/Dynamic_Map.html"), selfcontained = T) 
	


