# Project Summary  
This project includes an example of how to use R and an open API geocoding service operated by Oregon Department of Administrative Services (DAS).  More information about the service itself including the meta-data can be found at the following link https://navigator.state.or.us/arcgis/rest/services/Locators/gc_Composite/GeocodeServer


This repository includes a small random set of Oregon addresses to test the scripts and show how this service works using R.

# Script Details  
Two scripts are available in this repository.  The DAS_geocode_service_API.r script will decode addresses iteratively using a slower for loop while DAS_parallel_geocode_service_API.r uses a similar appraoch but 
is set up to do the geocoding using parallelization which, depending on the number of available cores, can significantly decrease processing time.  

### DAS_geocode_service_API.r <br/>
the sample address file (from the /Data folder) and a batch query to get the spatial coordiantes of the address.  The results
are then post-processed finding the highest scoring results and filtering our results that only returned the centroid of the zipcode in which the address was found.  Results that are only at the zipcode level may be useful for some purposes
but in many cases are too course for analysis and so are discarded.  The zipcode level results are usually returned becuase the address used for geocoding was not specific enough, typcially missing the address and only inlcuding hte zipcode and city.  


## download_format_FARS_data.r  
This script downloads raw FARS data from NHTSA FTP site and formats it for analysis.  Working with all the files through the NHTSA FTP site can be challenging and this script is meant to simplify pulling 
all the files and preparing for this analysis.  Other analyses would likely require preparing the data in different way but this should get you started. Starting in 2019 NHTSA stopped putting the Race 
data element in the person records and you know have to join it from a separate file becuase NHTSA now takes multiple races, if reported on death certificate, and includes them in this new race table.  
This script only uses the first reported race from the race table to be consistent with past data but for 
multi-race persons these data would be need to be processed differently.  This script works in 3 steps:  
### Step 1 -  Download Raw Data - Download zipped files and unzip them to local drive
### Step 2 -  Process Person Table Records - Prepare person table data for analysis
### Step 3 -  Finalize Formatting - Make final preprarations to ease merging with race and age cohort Census data elements

## download_prepare_census_population_data.r  
This script uses R's Census API tools to download and format state level population data for use in calculating age-adjusted population-based fatal injury rates for traffic injury. If other Census data elements are of interest beyond population
by age and race this script would need to be modified.   

## analyze_fars_race_prod.r
This script combines FARS person level fatal death data with Census population data to calculate age-adjusted population-based fatal injury rates by racial category.  The analysis uses the US population as the standard population to 
weight the rates by age cohort in order to make the composite rates by race comparable across the US.  A composite BIPOC rate is constructed to improve confidence in the point estimates for these non-White racial categories since some disaggregate BIPOC groups have small numbers of either population, injuries, or both.  

## Results  
Information featured in charts below are examples of information produced by this repository.  Repository materials are capable of producing other information on rates for other modes (bicycle, motor vehicle).
### Fatal Pedestrian Injury Rates 2014-2018
![Ped_Rates_2014-2018](www/Ped_Rates_2014-2018.png)  
### Fatal Pedestrian Injury Rates Over Time
![Ped_Rates_2014-2018](www/Ped_Rates_Over_Time.png)  
