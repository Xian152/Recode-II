////////////////////////////////////////////////////////////////////////////////////////////////////
*** DHS MONITORING: II
////////////////////////////////////////////////////////////////////////////////////////////////////

version 15.1
clear all
set matsize 3956, permanent
set more off, permanent
set maxvar 32767, permanent
capture log close
sca drop _all
matrix drop _all
macro drop _all

******************************
*** Define main root paths ***
******************************

//NOTE FOR WINDOWS USERS : use "/" instead of "\" in your paths

global root "/Users/xianzhang/Dropbox/DHS"

* Define path for data sources
global SOURCE "/Users/xianzhang/Desktop/Recode II"

* Define path for output data
global OUT "${root}/STATA/DATA/SC/FINAL"

* Define path for INTERMEDIATE
global INTER "${root}/STATA/DATA/SC/INTER"

* Define path for do-files
global DO "${root}/STATA/DO/SC/DHS/Recode II"

* Define the country names (in globals) in by Recode
do "${DO}/0_GLOBAL.do"
global mc "/Users/xianzhang/Dropbox"

// Brazil1991 BurkinaFaso1993 Cameroon1991 Colombia1990 DominicanRepublic1991 Egypt1992 Ghana1993 India1992 Indonesia1991 Jordan1990 
// Kenya1993 Madagascar1992 Malawi1992 Morocco1992 Namibia1992 Niger1992 Nigeria1990 Pakistan1990 Paraguay1990 Peru1991 
// Philippines1993  Rwanda1992  Senegal1992 Senegal1997  Tanzania1991 Turkey1993 Yemen1991  Zambia1992           
             

foreach name in   India1992 { //{

tempfile birth ind men hm hiv hh wi zsc iso 

************************************
***domains using zsc data***********
************************************

capture confirm file "${SOURCE}/DHS-`name'/DHS-`name'zsc.DTA"	
if _rc == 0 {
    use "${SOURCE}/DHS-`name'/DHS-`name'zsc.dta", clear
	
    if hwlevel == 2 {
		gen caseid = hwcaseid
		gen bidx = hwline   	
		gen name = "`name'"
		if inlist(name,"DominicanRepublic1991"){
			tempfile DRbirth
			preserve
			use "${SOURCE}/DHS-`name'/DHS-`name'birth.dta",clear
			duplicates drop caseid bidx,force // drop 5 duplicates 
			save `DRbirth',replace
			restore 
			merge 1:1 caseid bidx using `DRbirth'
		}
		else merge 1:1 caseid bidx using "${SOURCE}/DHS-`name'/DHS-`name'birth.dta"
    	gen ant_sampleweight = v005/10e6  
    	drop if _!=3
		
  		foreach var in hc70 hc71 {
  	 	replace `var'=. if `var'>900
  	 	replace `var'=`var'/100
  		}
  		replace hc70=. if hc70<-6 | hc70>6
  		replace hc71=. if hc71<-6 | hc71>5
 		gen c_stunted=1 if hc70<-2
 		replace c_stunted=0 if hc70>=-2 & hc70!=.
 		gen c_underweight=1 if hc71<-2
 		replace c_underweight=0 if hc71>=-2 & hc71!=.
		
		rename ant_sampleweight c_ant_sampleweight 
		keep c_* caseid bidx hwlevel hc70 hc71
		save "${INTER}/zsc_birth.dta",replace
    }

 	if hwlevel == 1 {
 		gen hhid = hwhhid
 		gen hvidx = hwline
 		merge 1:1 hhid hvidx using "${SOURCE}/DHS-`name'/DHS-`name'hm.dta", keepusing(hv103 hv001 hv002 hv005)
 		drop if hv103==0
 		gen ant_sampleweight = hv005/10e6
 		drop if _!=3
		gen ant_hm = 1
		
  		foreach var in hc70 hc71 {
  	 	replace `var'=. if `var'>900
  	 	replace `var'=`var'/100
  		}
  		replace hc70=. if hc70<-6 | hc70>6
  		replace hc71=. if hc71<-6 | hc71>5
 		gen c_stunted=1 if hc70<-2
 		replace c_stunted=0 if hc70>=-2 & hc70!=.
 		gen c_underweight=1 if hc71<-2
 		replace c_underweight=0 if hc71>=-2 & hc71!=.
	    
		rename ant_sampleweight c_ant_sampleweight
		keep c_* hhid hvidx hc70 hc71
		save "${INTER}/zsc_hm.dta",replace 
    }

 }
 
 

******************************
*****domains using birth data*
******************************
use "${SOURCE}/DHS-`name'/DHS-`name'birth.dta", clear	

    gen hm_age_mon = (v008 - b3)           //hm_age_mon Age in months (children only)
    gen name = "`name'"
	
    do "${DO}/1_antenatal_care"
    do "${DO}/2_delivery_care"
    do "${DO}/3_postnatal_care"
    do "${DO}/7_child_vaccination"
    do "${DO}/8_child_illness"
    do "${DO}/10_child_mortality"
    do "${DO}/11_child_other"
	
	capture confirm file "${INTER}/zsc_birth.dta"
	if _rc == 0 {
	merge 1:1 caseid bidx using "${INTER}/zsc_birth.dta",nogen
	rename (hc70 hc71) (c_hc70 c_hc71)
    }
	
*housekeeping for birthdata
   //generate the demographics for child who are dead or no longer living in the hh. 
   
    *hm_live Alive (1/0)
    recode b5 (1=0)(0=1) , ge(hm_live)   
	label var hm_live "died" 
	label define yesno 0 "No" 1 "Yes"
	label values hm_live yesno 

    *hm_dob	date of birth (cmc)
    gen hm_dob = b3  

    *hm_age_yrs	Age in years       
    gen hm_age_yrs = b8        

    *hm_male Male (1/0)         
    recode b4 (2 = 0),gen(hm_male)  
	
    *hm_doi	date of interview (cmc)
    gen hm_doi = v008
	
	*generate b16 as place holder
	//b16 Child's line number in household is missing in Recode III
	//gen b16 = s219  //s219 as alternative in Bangladesh1999, please check this by survey.
    cap gen b16 = . 
	
	*identify the case where there is no child line info in hm.dta 
    mdesc b16 
    gen miss_b16 = 1 if r(percent) == 100 

if miss_b16 != 1 {
rename (v001 v002 b16) (hv001 hv002 hvidx)
}

if miss_b16 == 1 {
rename (v001 v002 v003) (hv001 hv002 hvidx) //v003 in birth.dta: mother's line number
}

keep hv001 hv002 hvidx bidx c_* mor_* w_* hm_* 
save `birth'


******************************
*****domains using ind data***
******************************
use "${SOURCE}/DHS-`name'/DHS-`name'ind.dta", clear	
gen name = "`name'"
gen hm_age_yrs = v012
if inlist(name,"DominicanRepublic1991"){
	duplicates drop caseid,force // drop 2 duplicates 
}
    do "${DO}/4_sexual_health"
    do "${DO}/5_woman_anthropometrics"
    do "${DO}/16_woman_cancer"
*housekeeping for ind data

    *hm_dob	date of birth (cmc)
    gen hm_dob = v011  
	
	
keep v001 v002 v003 w_* hm_* 
rename (v001 v002 v003) (hv001 hv002 hvidx)
save `ind' 


************************************
*****domains using hm level data****
************************************
use "${SOURCE}/DHS-`name'/DHS-`name'hm.dta", clear
gen name = "`name'"
	duplicates drop
    do "${DO}/13_adult"
    do "${DO}/14_demographics"
	
capture confirm file "${INTER}/zsc_hm.dta"
	if _rc == 0 {
	merge 1:1 hhid hvidx using "${INTER}/zsc_hm.dta",nogen
	rename (hc70 hc71) (hm_hc70 hm_hc71)
	}
	
    if _rc != 0 {
	  capture confirm file "${INTER}/zsc_birth.dta"
	    if _rc != 0 {
          do "${DO}/9_child_anthropometrics"  //if there's no zsc related file, then run 9_child_anthropometrics
	      rename ant_sampleweight c_ant_sampleweight
		}
    }	
	
gen c_placeholder = 1
keep hv001 hv002 hvidx  ///
a_* hm_* ln c_*  
cap gen hm_shstruct =999
save `hm'

capture confirm file "${SOURCE}/DHS-`name'/DHS-`name'hiv.dta"
 	if _rc==0 {
    use "${SOURCE}/DHS-`name'/DHS-`name'hiv.dta", clear
    do "${DO}/12_hiv"
 	}
 	if _rc!= 0 {
    gen a_hiv = . 
    gen a_hiv_sampleweight = .
    }  
cap gen hm_shstruct =999
keep a_hiv* hv001 hm_shstruct hv002 hvidx 
save `hiv'

use `hm',clear
merge 1:1 hv001 hm_shstruct hv002 hvidx using `hiv'
drop _merge
save `hm',replace

************************************
*****domains using hh level data****
************************************
gen name = "`name'"
if !inlist(name,"Brazil1991","Cameroon1991","Colombia1990","DominicanRepublic1991","Niger1992"){
use "${SOURCE}/DHS-`name'/DHS-`name'hm.dta", clear
    rename (hv001 hv002 hvidx) (v001 v002 v003)

    merge 1:m v001 v002 v003 using "${SOURCE}/DHS-`name'/DHS-`name'birth.dta"
    rename (v001 v002 v003) (hv001 hv002 hvidx) 
    drop _merge
	cap gen hm_shstruct =999 
	gen name = "`name'"
}

* For Brazil1991, the v001/v002 lost 2-3 digits, fix this issue in main.do, 1.do,4.do,12.do & 13.do
if inlist(name,"Brazil1991","Cameroon1991","Colombia1990","DominicanRepublic1991","Niger1992"){
	tempfile birthspec
	if inlist(name,"Brazil1991"){
		use "${SOURCE}/DHS-Brazil1991/DHS-Brazil1991birth.dta",clear
		ren v023 hm_shstruct
		save `birthspec',replace
		
		use "${SOURCE}/DHS-Brazil1991/DHS-Brazil1991hm.dta", clear
		ren hv023 hm_shstruct
		order hhid hv000 hm_shstruct hv001 hv002 hvidx
		gen name = "`name'"
	}
	if inlist(name,"Cameroon1991"){
		use "${SOURCE}/DHS-Cameroon1991/DHS-Cameroon1991birth.dta",clear
		drop v002
		gen v002 = substr(caseid,11,2)
		gen hm_shstruct = substr(caseid,8,3)
		destring hm_shstruct v002,replace
		save `birthspec',replace

		use "${SOURCE}/DHS-Cameroon1991/DHS-Cameroon1991hm.dta", clear
		drop hv002
		ren (shstruct shmenage) (hm_shstruct hv002)
		gen name = "`name'"	
	}
	if inlist(name,"Colombia1990"){
		use "${SOURCE}/DHS-Colombia1990/DHS-Colombia1990birth.dta",clear
		drop v002
		gen v002 = substr(caseid,10,3)
		destring v002,replace
		gen hm_shstruct = 999
		save `birthspec',replace
		
		use "${SOURCE}/DHS-Colombia1990/DHS-Colombia1990hm.dta", clear
		drop hv002
		gen hv002 = substr(hhid,10,3)
		destring hv002,replace
		gen name = "`name'"
	}
	if inlist(name,"DominicanRepublic1991"){
		use "${SOURCE}/DHS-DominicanRepublic1991/DHS-DominicanRepublic1991birth.dta",clear
		gen hm_shstruct = substr(caseid,8,3)
		destring hm_shstruct,replace
		save `birthspec',replace
		
		use "${SOURCE}/DHS-DominicanRepublic1991/DHS-DominicanRepublic1991hm.dta", clear
		duplicates drop 
		ren shvivi hm_shstruct 
		gen name = "`name'"
	}
	if inlist(name,"Niger1992"){
		use "${SOURCE}/DHS-Niger1992/DHS-Niger1992birth.dta",clear
		gen hm_shstruct = substr(caseid,8,3)
		destring hm_shstruct,replace
		save `birthspec',replace
		
		use "${SOURCE}/DHS-Niger1992/DHS-Niger1992hm.dta", clear
		duplicates drop 
		ren shstruct hm_shstruct 
		gen name = "`name'"
	}
    rename (hv001 hv002 hvidx) (v001 v002 v003)

    merge 1:m v001 hm_shstruct v002 v003 using `birthspec'

    rename (v001 v002 v003) (hv001 hv002 hvidx) 
    drop _merge
}

************************************
*****domains using wi data**********
************************************
capture confirm file "${SOURCE}/DHS-`name'/DHS-`name'wi.dta"
    if _rc == 0 {
	preserve
		use "${SOURCE}/DHS-`name'/DHS-`name'wi.dta", clear
		ren whhid hhid 
		ren wlthindf hv271
		ren wlthind5 hv270
		sort hhid
		save `wi', replace 
	restore
	
	*merge with 
	merge m:1 hhid using `wi',nogen
	}
    do "${DO}/15_household"
	
cap gen hm_shstruct = 999	
keep hhid hv001 hm_shstruct hv002 hv003 hh_* 
save `hh',replace

************************************
*****merge to microdata*************
************************************
***match with external iso data
use "${SOURCE}/external/iso", clear 
keep country iso2c iso3c
replace country = "BurkinaFaso" if country == "Burkina Faso"
replace country = "DominicanRepublic" if country == "Dominican Republic"
replace country = "Moldova" if country == "Moldova, Republic of"
replace country = "Tanzania" if country == "Tanzania, United Republic of"
save `iso'

***merge all subset of microdata
use `birth',clear 
mdesc hvidx //identify the case where there is no child line info in hm.dta 
gen miss_b16 = 1 if r(percent) == 100 

if miss_b16 == 1 {
   //when b16 is missing, the hm.dta can not be merged with birth.dta, the final microdata would be women and child only.
  
    merge m:1 hv001 hm_shstruct hv002 hvidx using `ind',nogen update //merge child in birth.dta to mother in ind.dta
    merge m:m hv001 hm_shstruct hv002       using `hh',nogen update 
}

if miss_b16 != 1 {

  use `hm',clear //when b16 is not missing, the hm.dta can be merged with birth.dta, the final microdata has all household member info

    merge 1:m hv001 hm_shstruct hv002 hvidx using `birth',update              //missing update is zero, non missing conflict for all matched.(hvidx different) 
    replace hm_headrel = 99 if _merge == 2
	label define hm_headrel_lab 99 "dead/no longer in the household"
	label values hm_headrel hm_headrel_lab
	replace hm_live = 0 if _merge == 2 | inlist(hm_headrel,.,12,98)
	drop _merge
    merge m:m hv001 hm_shstruct hv002 hvidx using `ind',nogen update
	merge m:m hv001 hm_shstruct hv002       using `hh',nogen update 
   
    tab hh_urban,mi  //check whether all hh member + dead child + child lives outside hh assinged hh info
}



capture confirm variable c_hc70 c_hc71 
if _rc == 0 {
rename (c_hc70 c_hc71) (hc70 hc71)
}

capture confirm variable hm_hc70 hm_hc71 
if _rc == 0 {
rename (hm_hc70 hm_hc71 ) (hc70 hc71)
}

rename c_ant_sampleweight ant_sampleweight
drop c_placeholder

***survey level data
    gen survey = "DHS-`name'"
	gen year = real(substr("`name'",-4,.))
	tostring(year),replace
    gen country = regexs(0) if regexm("`name'","([a-zA-Z]+)")
	
    merge m:1 country using `iso',force
    drop if _merge == 2
	drop _merge

*** Quality Control: Validate with DHS official data
gen surveyid = iso2c+year+"DHS"
gen name = "`name'"

* to match with HEFPI_DHS.dta surveyid (differ in year)
	if inlist(name,"BurkinaFaso1993") {
		replace surveyid = "BF1992DHS"
	}
	
preserve
	do "${DO}/Quality_control"
	save "${INTER}/quality_control-`name'",replace
	cd "${INTER}"
	do "${DO}/Quality_control_result"
	save "${OUT}/quality_control",replace 
restore 


	
*** Specify sample size to HEFPI
	
    ***for variables generated from 1_antenatal_care 2_delivery_care 3_postnatal_care
	foreach var of var c_anc	c_anc_any	c_anc_bp	c_anc_bp_q	c_anc_bs	c_anc_bs_q ///
	c_anc_ear	c_anc_ear_q	c_anc_eff	c_anc_eff_q	c_anc_eff2	c_anc_eff2_q ///
	c_anc_eff3	c_anc_eff3_q	c_anc_ir	c_anc_ir_q	c_anc_ski	c_anc_ski_q ///
	c_anc_tet	c_anc_tet_q	c_anc_ur	c_anc_ur_q	c_caesarean	c_earlybreast ///
	c_facdel	c_hospdel	c_sba	c_sba_eff1	c_sba_eff1_q	c_sba_eff2 ///
	c_sba_eff2_q	c_sba_q	c_skin2skin	c_pnc_any	c_pnc_eff	c_pnc_eff_q c_pnc_eff2	c_pnc_eff2_q {
    replace `var' = . if !(inrange(hm_age_mon,0,23)& bidx ==1)
    }
	
	***for variables generated from 7_child_vaccination
	foreach var of var c_bcg c_dpt1 c_dpt2 c_dpt3 c_fullimm c_measles ///
	c_polio1 c_polio2 c_polio3{
    replace `var' = . if !inrange(hm_age_mon,15,23)
    }
	
	***for variables generated from 8_child_illness	
	foreach var of var c_ari	c_diarrhea 	c_diarrhea_hmf	c_diarrhea_medfor	c_diarrhea_mof	c_diarrhea_pro	c_diarrheaact ///
	c_diarrheaact_q	c_fever	c_fevertreat	c_illness	c_illtreat	c_sevdiarrhea	c_sevdiarrheatreat ///
	c_sevdiarrheatreat_q	c_treatARI c_treatARI2	c_treatdiarrhea	c_diarrhea_med {
    replace `var' = . if !inrange(hm_age_mon,0,59)
    }
	
	***for vriables generated from 9_child_anthropometrics
	foreach var of var c_underweight hc70 hc71 c_stunted ant_sampleweight{
    replace `var' = . if !inrange(hm_age_mon,0,59)
    }
	
	***for hive indicators from 12_hiv
	foreach var of var a_hiv*{
	replace `var'=. if hm_age_yrs<15 | (hm_age_yrs>49 & hm_age_yrs!=.)
    }	
	
	***for hive indicators from 13_adult
	foreach var of var a_diab_treat	a_inpatient_1y a_bp_treat a_bp_sys a_bp_dial a_hi_bp140_or_on_med a_bp_meas{
    replace `var'=. if hm_age_yrs<18
    }
	
*** Label variables
    drop bidx surveyid
    do "${DO}/Label_var" 
	
*** Clean the intermediate data
    capture confirm file "${INTER}/zsc_birth.dta"
    if _rc == 0 {
    erase "${INTER}/zsc_birth.dta"
    }	
    
	capture confirm file"${INTER}/zsc_hm.dta"
    if _rc == 0 {
    erase "${INTER}/zsc_hm.dta"
    }	  

	
save "${OUT}/DHS-`name'.dta", replace   
}




