file close _all 
set more off
global create_date = c(current_date)

* For audit survey import do-file, run this do-file with one argument "audit",
* as in "do import.do audit". The local `1' will contain the value of the first
* argument, in this case "audit". Otherwise, the first argument will be empty, 
* and this do-file will use the values for the main survey as specified in the
* globals do-file.

di "$survey_file"
di "$form_title"
di "$activity"


********************************************************************************
*  Read settings sheet from survey for survey version and default language     *
********************************************************************************

import excel "$survey_file", sheet("settings") firstrow clear
keep form_title form_id version default_language
drop if form_id == ""

global form_title = "`=form_title[1]'"
global version = `=version[1]'
global language = "`=default_language[1]'"
global lablang = "label" + "$language"
global filenum "2"

********************************************************************************
*      Open/create do-file and write do-file header with relevant info         *
********************************************************************************

file open imp using "2_Dofiles/${filenum}_Import_${form_title}.do", write replace

file write imp _n ///
"********************************************************************************" _n ///
"* Import Do-File for $form_title version $version" _n ///
"* Date of creation: $create_date" _n ///
"* Language: $language" _n ///
"********************************************************************************" _n(2)


*define program that labels the variables inside repeat groups.
file write imp _n ///
"*define program that labels the variables inside repeat groups." _n ///
"cap program drop labelrepeats" _n ///
"program define labelrepeats" _n ///
"args stem label" _n(2) ///
"foreach var of var \`stem'* {" _n ///
_char(9) "local dummy = substr(" _char(34) "\`var'" _char(34) ", strlen(" _char(34) "\`stem'" _char(34) ")+2, .)" _n ///
_char(9) "if regexm(" _char(34)" \`dummy'" _char(34) ", " _char(34) "[0-9]" _char(34) ") | regexm(" _char(34) "\`dummy'" _char(34) ", " _char(34) "[0-9][0-9]" _char(34) ") {" _n ///
_char(9) "di " _char(34) "\`var'" _char(34) _n ///
_char(9) _char(9)  "label var \`var' " _char(34) "\`label'" _char(34) _n ///
_char(9) "}" _n ///
"}" _n(2) ///
"end" _n(2)

*define program that labels the variables inside nested repeat groups.
file write imp _n ///
"*define program that labels the variables inside nested repeat groups." _n ///
"cap program drop nestedlabelrepeats" _n ///
"program define nestedlabelrepeats" _n ///
"args stem label" _n(2) ///
"foreach var of var \`stem'* {" _n ///
_char(9) "local dummy = substr(" _char(34) "\`var'" _char(34) ", strlen(" _char(34) "\`stem'" _char(34) ")+2, .)" _n ///
_char(9) "cap local dummy2 = 2*\`dummy'" _n ///
_char(9) "	if regexm(" _char(34) "\`dummy'" _char(34) ", " _char(34) "[0-9]_[0-9]" _char(34) ") | regexm(" _char(34) "\`dummy'" _char(34) ", " _char(34) "[0-9][0-9]_[0-9]" _char(34) ") | regexm(" _char(34) "\`dummy'" _char(34) ", " _char(34) "[0-9]_[0-9][0-9]" _char(34) ") | regexm(" _char(34) "\`dummy'" _char(34) ", " _char(34) "[0-9][0-9]_[0-9][0-9]" _char(34) ") {" _n ///
_char(9) "di " _char(34) "\`var'" _char(34) _n ///
_char(9) _char(9)  "label var \`var' " _char(34) "\`label'" _char(34) _n ///
_char(9) "}" _n ///
"}" _n(2) ///
"end" _n(2)

*define program that adds characteristics to all vars with a given suffix
file write imp _n ///
"*define program that adds characteristics to al vars with a given suffix" _n ///
"cap program drop charmult" _n ///
"program define charmult" _n ///
"args stem label" _n(2) ///
"cap des \`stem'" _n /// 
"if !_rc {" _n ///
_char(9) "foreach var of var \`stem' {" _n ///
_char(9) _char(9) "char \`var'[mult] Yes" _n ///
_char(9) "}" _n ///
"}" _n(2) ///
"end" _n(2)


file write imp ///
"import delimited " _char(34) "\$dataraw\1_Raw/CSVs/${form_title}_WIDE.csv" _char(34) ", varn(1) case(preserve) clear" _n(2) ///
"global dtafile " _char(34) "\$data\2_\${project}_\${activity}_imported.dta" _char(34) _n(2) ///
"replace KEY = instanceID if KEY == " _char(34) _char(34) _n ///
"drop instanceID" _n(2)


********************************************************************************
*         Import choices sheet from survey to generate value labels            *
********************************************************************************

clear

import excel "$survey_file", sheet("choices") firstrow

* For surveys with multiple languages, use the labels for default language,
* otherwise just use the single "label"
qui ds label*
if strpos("`r(varlist)'", "$lablang") {
	global labvar $lablang
}
else {
	global labvar "label"
}

rename value name
keep list_name name $labvar
drop if list_name == ""

* Force 32,000 character limit on value labels (probably unnecessary)
replace $labvar = substr($labvar, 1, 31999)
* Replace new line characters with space
replace $labvar = subinstr($labvar, char(10), " ", .)

replace $labvar = subinstr($labvar, char(34), "'", .)
replace $labvar = trim($labvar)
cap tostring name, replace force
replace list_name = trim(list_name)
replace name = trim(name)

* Exit with error if labels are duplicated
isid(list_name name)

* Destring name and drop 
qui destring name, replace force
drop if name == .
sort list_name name

* Generate position in each label
bys list_name: gen resno = _n
* Generate length of each label
bys list_name: gen len = _N

file write imp "* Defining value labels for all choices" _n(2) ///
"#delimit ;" _n

* Loop through each label value (each "observation" in choices sheet)
count
forval i = 1/`r(N)' {
	* For first label value, write "label define" command to do-file
	if `=resno[`i']' == 1 {
		file write imp "label define `=list_name[`i']' `=name[`i']' " _char(34) "`=$labvar[`i']'" _char(34) _n
	}
	
	else if `=resno[`i']' > 1 & `=resno[`i']' < `=len[`i']' {
		file write imp _char(9) "`=name[`i']' " _char(34) "`=$labvar[`i']'" _char(34) _n
	}
	
	* Add semicolon delimiter for last value in label
	else if `=resno[`i']' == `=len[`i']' {
		file write imp _char(9) "`=name[`i']' " _char(34) "`=$labvar[`i']'" _char(34) ";" _n(2)
	}
}

file write imp "#delimit cr" _n(2)

********************************************************************************
*                           Process survey sheet                               *
********************************************************************************

clear

import excel "$survey_file", sheet("survey") firstrow

* For surveys with multiple languages, use the labels for default language,
* otherwise just use the single "label"
qui ds label*
if strpos("`r(varlist)'", "$lablang") {
	global labvar $lablang
}
else {
	global labvar "label"
}

cap gen programming = .
keep type name $labvar programming

drop if type == ""

replace $labvar = substr($labvar, 1, 79)
replace $labvar = subinstr($labvar, char(10), " ", .)
replace $labvar = subinstr($labvar, char(34), "'", .)
replace $labvar = trim($labvar)
cap tostring name, replace force
replace name = trim(name)
replace type = trim(type)


* Generate indicator for repeated fields:
gen repeated = 0
global x = 0
count
forval i = 1/`r(N)' {
	if "`=type[`i']'"=="begin repeat" {
		global x = $x + 1
	}
	else if "`=type[`i']'"=="end repeat" {
		global x = $x - 1
	}
	
	if $x >= 1 qui replace repeated = $x if _n == `i'
}

* Process text and calculate fields to tostring:
preserve
	keep if type == "text" | type == "calculate"
	drop if programming == 1
	global txt
	count
	forval i = 1/`r(N)' {
		if `=repeated[`i']' == 0 {
			global txt = "$txt " + "`=name[`i']'"
		}
		
		else if `=repeated[`i']' == 1 {
			global txt = "$txt " + "`=name[`i']'" + "*"
		}
	}
restore

local x = 1
foreach word in $txt {
	if `x' == 1 { 
		file write imp "* To-string all text and calculate fields:" _n ///
		"#delimit ;" _n "local tslist `word'" _n
	}
	
	else if "`ferest()'" != "" {
		file write imp _char(9) "`word'" _n
	}	
	
	else if "`ferest()'" == "" {
		file write imp _char(9) "`word';" _n ///
		"#delimit cr" _n(2)
	}
	
	local ++x
}

file write imp "foreach stub in \`tslist' {" _n ///
_char(9) "cap unab x: \`stub'" _n ///
_char(9) "if !_rc {" _n ///
_char(9) _char(9) "foreach var in \`x' {" _n ///
_char(9) _char(9) _char(9) "tostring \`var', replace force" _n ///
_char(9) _char(9) "}" _n ///
_char(9) "}" _n ///
_char(9) "else {" _n  ///
_char(9) _char(9) "di " _char(34) "\`stub' do(es) not exist (yet)" _char(34) _n ///
_char(9) "}" _n ///
"}" _n(2)

* Process integer and decimal fields to destring:
preserve
	keep if type == "integer" | type == "decimal"
	drop if programming == 1
	global num
	count
	forval i = 1/`r(N)' {
		if `=repeated[`i']' == 0 {
			global num = "$num " + "`=name[`i']'"
		}
		
		else if `=repeated[`i']' == 1 {
			global num = "$num " + "`=name[`i']'" + "*"
		}
	}
restore

local x = 1
foreach word in $num {
	if `x' == 1 { 
		file write imp "* Destring all integer and decimal fields:" _n ///
		"#delimit ;" _n "local dslist `word'" _n
	}
	
	else if "`ferest()'" != "" {
		file write imp _char(9) "`word'" _n
	}	
	
	else if "`ferest()'" == "" {
		file write imp _char(9) "`word';" _n ///
		"#delimit cr" _n(2)
	}
	
	local ++x
}

file write imp "foreach stub in \`dslist' {" _n ///
_char(9) "cap unab x: \`stub'" _n ///
_char(9) "if !_rc {" _n ///
_char(9) _char(9) "foreach var in \`x' {" _n ///
_char(9) _char(9) _char(9) "destring \`var', replace force" _n ///
_char(9) _char(9) "}" _n ///
_char(9) "}" _n ///
_char(9) "else {" _n  ///
_char(9) _char(9) "di " _char(34) "\`stub' do(es) not exist (yet)" _char(34) _n ///
_char(9) "}" _n ///
"}" _n(2)

* Process note fields to drop:
preserve
	keep if type == "note"
	global nts
	count
	forval i = 1/`r(N)' {
		if `=repeated[`i']' == 0 {
			global nts = "$nts " + "`=name[`i']'"
		}
		
		else if `=repeated[`i']' == 1 {
			global nts = "$nts " + "`=name[`i']'" + "*"
		}
	}
restore

local x = 1
foreach word in $nts {
	if `x' == 1 {
		file write imp "* Dropping all note fields:" _n ///
		"#delimit ;" _n "local ntlist `word'" _n
	}
	
	else if "`ferest()'" != "" {
		file write imp _char(9) "`word'" _n
	}
	
	else if "`ferest()'" == "" {
		file write imp _char(9) "`word';" _n "#delimit cr" _n(2)
	}
	local ++x
}

file write imp "foreach stub in \`ntlist' {" _n ///
_char(9) "cap unab x: \`stub'" _n ///
_char(9) "if !_rc {" _n ///
_char(9) _char(9) "foreach var in \`x' {" _n ///
_char(9) _char(9) _char(9) "drop \`var'" _n ///
_char(9) _char(9) "}" _n ///
_char(9) "}" _n ///
_char(9) "else {" _n  ///
_char(9) _char(9) "di " _char(34) "\`stub' do(es) not exist (yet)" _char(34) _n ///
_char(9) "}" _n ///
"}" _n(2)


* Destring all select_one questions to value label
preserve
	keep if regexm(type, "select_one")
	drop if programming == 1
	global sel
	count
	forval i = 1/`r(N)' {
		if `=repeated[`i']' == 0 {
			global sel = "$sel " + "`=name[`i']'"
		}
		
		else if `=repeated[`i']' == 1 {
			global sel = "$sel " + "`=name[`i']'" + "*"
		}
	}
restore

local x = 1
foreach word in $sel {
	if `x' == 1 { 
		file write imp "* Destring all select_one fields for value labels:" _n ///
		"#delimit ;" _n "local solist `word'" _n
	}
	
	else if "`ferest()'" != "" {
		file write imp _char(9) "`word'" _n
	}	
	
	else if "`ferest()'" == "" {
		file write imp _char(9) "`word';" _n ///
		"#delimit cr" _n(2)
	}
	
	local ++x
}

file write imp "foreach stub in \`solist' {" _n ///
_char(9) "cap unab x: \`stub'" _n ///
_char(9) "if !_rc {" _n ///
_char(9) _char(9) "foreach var in \`x' {" _n ///
_char(9) _char(9) _char(9) "destring \`var', replace force" _n ///
_char(9) _char(9) "}" _n ///
_char(9) "}" _n ///
_char(9) "else {" _n  ///
_char(9) _char(9) "di " _char(34) "\`stub' do(es) not exist (yet)" _char(34) _n ///
_char(9) "}" _n ///
"}" _n(2)


file write imp "/*" _n
* Split select multiple questions and destring

preserve
	keep if regexm(type, "select_multiple")
	drop if programming == 1
	global mul
	count
	forval i = 1/`r(N)' {
		if `=repeated[`i']' == 0 {
			global mul = "$mul " + "`=name[`i']'"
		}
		
		else if `=repeated[`i']' == 1 {
			global mul = "$mul " + "`=name[`i']'" + "*"
		}
	}
restore

local x = 1
foreach word in $mul {
	if `x' == 1 {
		file write imp "* Split and destring all select_multiple vars:" _n ///
		"#delimit ;" _n "local smlist `word'" _n
	}
	
	else if "`ferest()'" != "" {
		file write imp _char(9) "`word'" _n
	}
	
	else if "`ferest()'" == "" {
		file write imp _char(9) "`word';" _n ///
		"#delimit cr" _n(2)
	}
	local ++x
}

file write imp "foreach stub in \`smlist' {" _n ///
_char(9) "cap unab x: \`stub'" _n ///
_char(9) "if !_rc {" _n ///
_char(9) _char(9) "foreach var in \`x' {" _n ///
_char(9) _char(9) _char(9) "cap confirm str v \`var'" _n ///
_char(9) _char(9) _char(9) "if !_rc {" _n ///
_char(9) _char(9) _char(9) _char(9) "char \`var'[multi] yes" _n ///
_char(9) _char(9) _char(9) _char(9) "split \`var', destring force" _n ///
_char(9) _char(9) _char(9) "}" _n ///
_char(9) _char(9) _char(9) "else {" _n ///
_char(9) _char(9) _char(9) _char(9) "di " _char(34) "\`var' is empty" _char(34) _n ///
_char(9) _char(9) _char(9) "}" _n ///
_char(9) _char(9) "}" _n ///
_char(9) "}" _n ///
_char(9) "else {" _n  ///
_char(9) _char(9) "di " _char(34) "\`stub' do(es) not exist (yet)" _char(34) _n ///
_char(9) "}" _n ///
"}" _n(2)


file write imp "*/" _n(2)

foreach word in $mul {
	file write imp "charmult `word'" _n
}

/*
file write imp "foreach var in \`r(varlist)' {" _n ///
_char(9) "split \`var', destring force" _n ///
"}" _n(2)
*/


* Format datetime fields:
preserve
	keep if type == "start" | type == "end" | type == "datetime"
	global dat "SubmissionDate"
	count
	forval i = 1/`r(N)' {
		if `=repeated[`i']' == 0 {
			global dat = "$dat " + "`=name[`i']'"
		}
		
		else if `=repeated[`i']' == 1 {
			global dat = "$dat " + "`=name[`i']'" + "*"
		}
	}
restore

local x = 1
foreach word in $dat {
	if `x' == 1 {
		file write imp "* Format all date and datetime variables:" _n ///
		"#delimit ;" _n "local dtlist `word'" _n
	}
	
	else if "`ferest()'" != "" {
		file write imp _char(9) "`word'" _n
	}
	
	else if "`ferest()'" == "" {
		file write imp _char(9) "`word';" _n ///
		"#delimit cr" _n(2)
	}
	local ++x
}	

file write imp "foreach stub in \`dtlist' {" _n ///
_char(9) "cap unab x: \`stub'" _n ///
_char(9) "if !_rc {" _n ///
_char(9) _char(9) "foreach var in \`x' {" _n ///
_char(9) _char(9) _char(9) "gen \`var'_X = clock(\`var', " _char(34) "MDYhms" _char(34) ")" _n ///
_char(9) _char(9) _char(9) "format \`var'_X %tc" _n ///
_char(9) _char(9) _char(9) "drop \`var'" _n ///
_char(9) _char(9) _char(9) "rename \`var'_X \`var'" _n ///
_char(9) _char(9) "}" _n ///
_char(9) "}" _n ///
_char(9) "else {" _n  ///
_char(9) _char(9) "di " _char(34) "\`stub' do(es) not exist (yet)" _char(34) _n ///
_char(9) "}" _n ///
"}" _n(2)



drop if regexm(type, "group|repeat|note")==1
drop if programming == 1
drop programming
*drop if regexm(name, "^dis_|^chk_|^ml_|^el_|^sum_|^pos_|^rep_|hhmem|filter|memage|^selected_|^lab_|^n_|^unit_") == 1


gen select_one = regexm(type, "select_one")
gen select_multiple = regexm(type, "select_multiple")

gen list_name = cond(select_one==1 | select_multiple==1, trim(regexr(type, "select_(one|multiple)", "")), "")

gen vallab = cond(select_one==1 & repeated == 0, "cap label val " + name + " " + list_name, ///
 cond(select_one==1 & repeated==1, "cap label val " + name + "* " + list_name, ""))
 


file write imp "* Adding value labels for all vars:" _n
count
forval i = 1/`r(N)' {
	if "`=vallab[`i']'" != "" {
		file write imp "`=vallab[`i']'" _n
	}
}

file write imp _n(2) "* Adding variable labels for non-repeated variables" _n



count
forval i = 1/`r(N)' {
	if `=repeated[`i']' == 0 & "`=$labvar[`i']'" != "" {
		file write imp "cap label var `=name[`i']' " _char(34) "`=$labvar[`i']'" _char(34) _n
	}
	if `=repeated[`i']' == 1 &"`=$labvar[`i']'" != "" {
		file write imp "cap labelrepeats `=name[`i']' " _char(34) "`=$labvar[`i']'" _char(34) _n
	}
	if `=repeated[`i']' > 1 &"`=$labvar[`i']'" != "" {
		file write imp "cap nestedlabelrepeats `=name[`i']' " _char(34) "`=$labvar[`i']'" _char(34) _n
	}

}


file write imp _n(2) "do " _char(34) "$do\02 Import\import_ubi_baseline_labelselectmultiple" _char(34) _n


********************************************************************************
*                     Append data to import .dta file                          *
********************************************************************************



file write imp _n(2) "* Append data from API to previous import .dta:" _n ///
"if " _char(34) "\$api_true" _char(34) "== " _char(34) "Yes" _char(34) " {" _n ///
 _char(9) "* Append old, previously imported data if any" _n ///
 _char(9) "cap confirm file " _char(34) "\$dtafile" _char(34) _n ///
 _char(9) "if _rc == 0 {" _n ///
 _char(9) _char(9) "* Append previous data with safeappend" _n ///
 _char(9) _char(9) "noisily cap safeappend using " _char(34) "\$dtafile" _char(34) _n ///
 _char(9) _char(9) "sort KEY SubmissionDate" _n ///
 _char(9) _char(9) "duplicates drop KEY, force" _n ///
 _char(9) "}" _n(2) ///
 _char(9) "else {" _n ///
 _char(9) _char(9) "sort KEY SubmissionDate" _n ///
 _char(9) _char(9) "duplicates drop KEY, force" _n ///
 _char(9) "}" _n(2) ///
 _char(9) "* Compress and save data to .dta format" _n ///
 _char(9) "qui compress _all" _n ///
 _char(9) "save " _char(34) "\${dtafile}_API.dta" _char(34) ", replace orphans" _n ///
 "}" _n(2) ///
 "* Or save full data to .dta if using SurveyCTO Sync:" _n ///
 "else {" _n ///
 _char(9) "sort KEY SubmissionDate" _n ///
 _char(9) "duplicates drop KEY, force" _n ///
 _char(9) "qui compress _all" _n ///
 _char(9) "save " _char(34) "\${dtafile}" _char(34) ", replace orphans" _n ///
 "}" _n(10)
 

file close imp
