/*
In this do-file I wrote caode that takes the surveyCTO excel file and pulls
out the select multiple questions and labels the indicator variables.

Created by: Simon Robertson
Date: 17th Feb 2016
*/

***Defining the program which pulls all the value labels for select multiple question from the survey CTO programming excel
cap program drop lblselectmulti
program define lblselectmulti

	*only arguement is the path to the surveyCTO programming excel. 
	args excelloc
	
	*store the open data set (this should be the survey data you want to label)
	tempfile maindata
	save "`maindata'", replace
	
	*local excelloc $excelloc

	clear all
	set more off
	*open the survey tab of the surveyCTO programming excel file
	import excel "`excelloc'", sheet("survey") firstrow
	*find all the select_multiple variables
	rename labelenglish label
	keep type name label
	gen selectmultiple = strpos(type, "select_multiple")
	keep if selectmultiple == 1
	drop selectmultiple
	gen multilabel = trim(substr(type, 16, . ))
	drop type

	*Store the variable names and choice names as locals
	count
	local count = `r(N)'
	forvalues i = 1/`count' {
		local x_`i' = name[`i']
		*di "`x_`i''"
		local z_`i' = multilabel[`i']
		*di "`z_`i''"
	}

	*Open the choices sheet of the same excel workbook
	import excel "`excelloc'", sheet("choices") firstrow clear
	rename value name
	rename labelenglish label
	keep list_name name label
	*keep the labels which are assigned to select multiple variables
	gen labelused = 0
	forvalues i = 1/`count' {
		replace labelused = 1 if list_name == "`z_`i''"
	}
	drop if labelused == 0
	drop labelused
	
	sort list_name name
	tostring name, replace
	by list_name, sort : gen responseno = _n
	gen num = _n
	*cycle through all of the choices storing the response code and response label in locals
	forvalues i=1/`count' {
		qui count if list_name == "`z_`i''"
		local w_`i' = `r(N)'
		forvalues j = 1/`w_`i'' {
			qui su num if list_name == "`z_`i''" & responseno == `j', meanonly 
			local r_`i'_`j' = name[`r(mean)']
			local l_`i'_`j' = subinstr(label[`r(mean)'], `"""', "'", .)
			di "`r_`i'_`j'' labelled as `l_`i'_`j''"
		}
	}


	*re-open the main dataset
	use "`maindata'", clear

	*I remove the labels from any variable whose label is a version of the variable name with capitals
	/*I think that if you have a variable name with capital letters in your surveyCTO file, then
	*When you import it assigns the capitalized name as the varaible and gives the lowercase version as the
	variable name.*/
	foreach var of var * {
		cap local lab : var label `var'
		if strpos(lower("`var'"), lower("`lab'")) >0 {
			cap label var `var' ""
		}	
	}
	*Now I cycle through all of the selectmultiple variables and then all of the
	*choices within that select multiple question.
	forvalues i=1/`count' {
		forvalues j = 1/`w_`i'' {
			di "`x_`i''_`r_`i'_`j'' needs to be labelled!!"
			*store old label as a local
			cap local lab : var label `x_`i''_`r_`i'_`j''
			*relabel variable if old label is empty
			if "`lab'" == "" | "`lab'" == " " {
				cap label var `x_`i''_`r_`i'_`j'' "`l_`i'_`j''"
			}
			*look for varaibles which are reshaped versions of each variable	
			cap des `x_`i''_`r_`i'_`j''_*, varlist
			*If these varaibles exist then I will relabel them also.
			if !_rc {
				foreach var of var `x_`i''_`r_`i'_`j''_* {
					cap local lab : var label `var'
					if "`lab'" == "" | "`lab'" == " " {
						di "`var'" "`l_`i'_`j''"
						label var `var' "`l_`i'_`j''"
					}	
				}	
			}	
		}
	}	
	*Also store each of the labels as a value label. This will be helpful for outputting the HFCs
	forvalues i=1/`count' {
		forvalues j = 1/`w_`i'' {
			label define `x_`i'' `r_`i'_`j'' "`l_`i'_`j''", modify
		}
	}		

	
end

***running the program****
lblselectmulti "$survey_file"

*Add labels for the negative options
foreach var of var *__222* {
	label var `var' "Other"
}
foreach var of var *__777* {
	label var `var' "Refused to answer"
}
foreach var of var *__999* {
	label var `var' "Don't know"
}

