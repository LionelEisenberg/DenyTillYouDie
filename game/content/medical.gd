class_name Medical
## Procedures, diagnoses, providers and plans the claim generator draws from.
##
## Priorities: 0 ROUTINE, 1 URGENT, 2 CRITICAL (see Claim.Priority).
## A diagnosis's `procs` are always billed; `pa_addons` and `excluded_addons`
## are what the generator adds when it plants an R-04 or R-06 violation.
## `history_label` is what shows up in the medical history when a chronic
## condition predates enrollment (R-05): the same condition, sometimes under
## another name ("Atrial flutter" for atrial fibrillation), but always sharing a
## word stem with the claim's label, so the match can be read off the paper.
## `fatal` is false for the few conditions nobody dies of untreated, so a
## denied patient with one of them never turns up in the obituaries.

const PROCEDURES: Dictionary = {
	# Visits
	"er_visit": {"label": "EMERGENCY ROOM VISIT", "cost": 1250, "pa": false, "excluded": false},
	"urgent_care": {"label": "URGENT CARE VISIT", "cost": 240, "pa": false, "excluded": false},
	"office_visit": {"label": "OFFICE VISIT", "cost": 180, "pa": false, "excluded": false},
	"oncology_consult": {"label": "ONCOLOGY CONSULTATION", "cost": 450, "pa": false, "excluded": false},
	"psych_eval": {"label": "PSYCHIATRIC EVALUATION", "cost": 650, "pa": false, "excluded": false},
	"prenatal_visit": {"label": "PRENATAL VISIT", "cost": 260, "pa": false, "excluded": false},
	# Tests and imaging
	"xray_wrist": {"label": "X-RAY, WRIST", "cost": 380, "pa": false, "excluded": false},
	"xray_ankle": {"label": "X-RAY, ANKLE", "cost": 360, "pa": false, "excluded": false},
	"xray_chest": {"label": "X-RAY, CHEST", "cost": 420, "pa": false, "excluded": false},
	"xray_hip": {"label": "X-RAY, HIP", "cost": 410, "pa": false, "excluded": false},
	"strep_test": {"label": "RAPID STREP TEST", "cost": 95, "pa": false, "excluded": false},
	"ear_exam": {"label": "OTOSCOPIC EXAM", "cost": 140, "pa": false, "excluded": false},
	"blood_panel": {"label": "BLOOD PANEL", "cost": 260, "pa": false, "excluded": false},
	"ecg": {"label": "ELECTROCARDIOGRAM", "cost": 210, "pa": false, "excluded": false},
	"ultrasound": {"label": "ULTRASOUND, ABDOMEN", "cost": 640, "pa": false, "excluded": false},
	"ob_ultrasound": {"label": "OBSTETRIC ULTRASOUND", "cost": 520, "pa": false, "excluded": false},
	"fetal_monitoring": {"label": "FETAL MONITORING", "cost": 1800, "pa": false, "excluded": false},
	"mri_ankle": {"label": "MRI, ANKLE", "cost": 2600, "pa": true, "excluded": false},
	"mri_knee": {"label": "MRI, KNEE", "cost": 2800, "pa": true, "excluded": false},
	"mri_spine": {"label": "MRI, LUMBAR SPINE", "cost": 3100, "pa": true, "excluded": false},
	"mri_brain": {"label": "MRI, BRAIN", "cost": 3400, "pa": true, "excluded": false},
	"ct_head": {"label": "CT SCAN, HEAD", "cost": 3200, "pa": true, "excluded": false},
	"ct_chest": {"label": "CT SCAN, CHEST", "cost": 3100, "pa": true, "excluded": false},
	"ct_abdomen": {"label": "CT SCAN, ABDOMEN", "cost": 3300, "pa": true, "excluded": false},
	"echo": {"label": "ECHOCARDIOGRAM", "cost": 1450, "pa": true, "excluded": false},
	"biopsy": {"label": "BIOPSY", "cost": 2600, "pa": true, "excluded": false},
	"bone_marrow_biopsy": {"label": "BONE MARROW BIOPSY", "cost": 4200, "pa": true, "excluded": false},
	# Treatments
	"cast": {"label": "CAST APPLICATION", "cost": 640, "pa": false, "excluded": false},
	"splint": {"label": "SPLINT/BRACE", "cost": 210, "pa": false, "excluded": false},
	"sutures": {"label": "LACERATION REPAIR", "cost": 890, "pa": false, "excluded": false},
	"antibiotics": {"label": "ANTIBIOTICS (10-DAY)", "cost": 60, "pa": false, "excluded": false},
	"nebulizer": {"label": "NEBULIZER TREATMENT", "cost": 310, "pa": false, "excluded": false},
	"inhaler": {"label": "RESCUE INHALER", "cost": 85, "pa": false, "excluded": false},
	"migraine_infusion": {"label": "IV MIGRAINE INFUSION", "cost": 980, "pa": false, "excluded": false},
	"pt_sessions": {"label": "PHYSICAL THERAPY (6 SESSIONS)", "cost": 1140, "pa": false, "excluded": false},
	"iv_fluids": {"label": "IV FLUIDS", "cost": 420, "pa": false, "excluded": false},
	"insulin": {"label": "INSULIN (30-DAY SUPPLY)", "cost": 340, "pa": false, "excluded": false},
	"bp_meds": {"label": "BLOOD PRESSURE MEDS (30-DAY)", "cost": 45, "pa": false, "excluded": false},
	"antidepressant": {"label": "ANTIDEPRESSANT (30-DAY)", "cost": 110, "pa": false, "excluded": false},
	"therapy_sessions": {"label": "PSYCHOTHERAPY (8 SESSIONS)", "cost": 1360, "pa": false, "excluded": false},
	"stroke_tpa": {"label": "CLOT-BUSTING DRUG (tPA)", "cost": 8900, "pa": false, "excluded": false},
	"observation": {"label": "HOSPITAL OBSERVATION (24H)", "cost": 4200, "pa": false, "excluded": false},
	"spinal_injection": {"label": "SPINAL STEROID INJECTION", "cost": 2100, "pa": true, "excluded": false},
	"tms": {"label": "MAGNETIC STIMULATION (TMS)", "cost": 9000, "pa": true, "excluded": false},
	"inpatient_stay": {"label": "INPATIENT ADMISSION (2 DAYS)", "cost": 9800, "pa": true, "excluded": false},
	"icu_stay": {"label": "ICU ADMISSION (3 DAYS)", "cost": 41000, "pa": true, "excluded": false},
	"rehab": {"label": "INPATIENT REHABILITATION", "cost": 22000, "pa": true, "excluded": false},
	"appendectomy": {"label": "APPENDECTOMY", "cost": 18400, "pa": true, "excluded": false},
	"acl_surgery": {"label": "ACL RECONSTRUCTION", "cost": 24000, "pa": true, "excluded": false},
	"hip_replacement": {"label": "TOTAL HIP REPLACEMENT", "cost": 38500, "pa": true, "excluded": false},
	"gallbladder": {"label": "GALLBLADDER REMOVAL", "cost": 16200, "pa": true, "excluded": false},
	"cardiac_cath": {"label": "CARDIAC CATHETERIZATION", "cost": 21000, "pa": true, "excluded": false},
	"stent": {"label": "CORONARY STENT", "cost": 32000, "pa": true, "excluded": false},
	"chemo": {"label": "CHEMOTHERAPY (CYCLE 1)", "cost": 28500, "pa": true, "excluded": false},
	"radiation": {"label": "RADIATION THERAPY", "cost": 19500, "pa": true, "excluded": false},
	"dialysis": {"label": "DIALYSIS (12 SESSIONS)", "cost": 14400, "pa": true, "excluded": false},
	# Exclusions list
	"proton_beam": {"label": "PROTON BEAM THERAPY", "cost": 86000, "pa": false, "excluded": true},
	"immunotherapy_exp": {"label": "EXPERIMENTAL IMMUNOTHERAPY", "cost": 142000, "pa": false, "excluded": true},
	"gene_therapy": {"label": "GENE THERAPY INFUSION", "cost": 210000, "pa": false, "excluded": true},
	"acupuncture": {"label": "ACUPUNCTURE (6 SESSIONS)", "cost": 540, "pa": false, "excluded": true},
	"chiropractic": {"label": "CHIROPRACTIC ADJUSTMENT", "cost": 320, "pa": false, "excluded": true},
	"prp_injection": {"label": "PLATELET-RICH PLASMA SHOT", "cost": 1500, "pa": false, "excluded": true},
	"air_ambulance": {"label": "AIR AMBULANCE TRANSPORT", "cost": 48000, "pa": false, "excluded": true},
	"glucose_monitor": {"label": "CONTINUOUS GLUCOSE MONITOR", "cost": 1200, "pa": false, "excluded": true},
	"massage": {"label": "MEDICAL MASSAGE THERAPY", "cost": 480, "pa": false, "excluded": true},
	"nerve_stim": {"label": "NERVE STIMULATION DEVICE", "cost": 6400, "pa": false, "excluded": true},
	"home_nursing": {"label": "HOME NURSING CARE", "cost": 3600, "pa": false, "excluded": true},
	"residential_mh": {"label": "RESIDENTIAL MENTAL HEALTH CARE", "cost": 18000, "pa": false, "excluded": true},
}

const DIAGNOSES: Array[Dictionary] = [
	# ROUTINE
	{"id": "wrist_fx", "label": "Fracture, left wrist", "condition": "wrist_fracture", "priority": 0,
		"procs": ["er_visit", "xray_wrist", "cast"], "pa_addons": [], "excluded_addons": ["massage"],
		"child_ok": true, "adult_ok": true, "chronic": false, "fatal": true, "history_label": ""},
	{"id": "ankle_sprain", "label": "Sprain, right ankle", "condition": "ankle_injury", "priority": 0,
		"procs": ["urgent_care", "xray_ankle", "splint"], "pa_addons": ["mri_ankle"], "excluded_addons": ["prp_injection", "massage"],
		"child_ok": true, "adult_ok": true, "chronic": false, "fatal": true, "history_label": ""},
	{"id": "laceration", "label": "Laceration, right hand", "condition": "laceration", "priority": 0,
		"procs": ["er_visit", "sutures"], "pa_addons": [], "excluded_addons": [],
		"child_ok": true, "adult_ok": true, "chronic": false, "fatal": true, "history_label": ""},
	{"id": "strep", "label": "Strep throat", "condition": "strep", "priority": 0,
		"procs": ["urgent_care", "strep_test", "antibiotics"], "pa_addons": [], "excluded_addons": [],
		"child_ok": true, "adult_ok": true, "chronic": false, "fatal": true, "history_label": ""},
	{"id": "ear_infection", "label": "Ear infection", "condition": "ear_infection", "priority": 0,
		"procs": ["office_visit", "ear_exam", "antibiotics"], "pa_addons": [], "excluded_addons": [],
		"child_ok": true, "adult_ok": false, "chronic": false, "fatal": true, "history_label": ""},
	{"id": "migraine", "label": "Migraine, severe", "condition": "migraine", "priority": 0,
		"procs": ["er_visit", "migraine_infusion"], "pa_addons": ["mri_brain", "ct_head"], "excluded_addons": ["acupuncture", "nerve_stim"],
		"child_ok": false, "adult_ok": true, "chronic": true, "fatal": true, "history_label": "Migraine (chronic)"},
	{"id": "back_strain", "label": "Lower back strain", "condition": "back_pain", "priority": 0,
		"procs": ["office_visit", "pt_sessions"], "pa_addons": ["mri_spine", "spinal_injection"], "excluded_addons": ["chiropractic", "acupuncture", "massage"],
		"child_ok": false, "adult_ok": true, "chronic": true, "fatal": true, "history_label": "Lower back pain"},
	{"id": "asthma_flare", "label": "Asthma flare-up", "condition": "asthma", "priority": 0,
		"procs": ["urgent_care", "nebulizer", "inhaler"], "pa_addons": ["inpatient_stay"], "excluded_addons": [],
		"child_ok": true, "adult_ok": true, "chronic": true, "fatal": true, "history_label": "Asthma"},
	{"id": "hypertension", "label": "Hypertension, uncontrolled", "condition": "hypertension", "priority": 0,
		"procs": ["office_visit", "ecg", "bp_meds"], "pa_addons": ["echo"], "excluded_addons": ["home_nursing"],
		"child_ok": false, "adult_ok": true, "chronic": true, "fatal": true, "history_label": "Hypertension"},
	{"id": "bronchitis", "label": "Acute bronchitis", "condition": "bronchitis", "priority": 0,
		"procs": ["urgent_care", "xray_chest", "antibiotics"], "pa_addons": ["ct_chest"], "excluded_addons": [],
		"child_ok": true, "adult_ok": true, "chronic": false, "fatal": true, "history_label": ""},
	# URGENT
	{"id": "pneumonia", "label": "Pneumonia", "condition": "pneumonia", "priority": 1,
		"procs": ["er_visit", "xray_chest", "iv_fluids", "antibiotics"], "pa_addons": ["inpatient_stay", "ct_chest"], "excluded_addons": ["home_nursing"],
		"child_ok": true, "adult_ok": true, "chronic": false, "fatal": true, "history_label": ""},
	{"id": "appendicitis", "label": "Acute appendicitis", "condition": "appendicitis", "priority": 1,
		"procs": ["er_visit", "ct_abdomen", "appendectomy"], "pa_addons": ["inpatient_stay"], "excluded_addons": [],
		"child_ok": true, "adult_ok": true, "chronic": false, "fatal": true, "history_label": ""},
	{"id": "croup", "label": "Croup, severe", "condition": "croup", "priority": 1,
		"procs": ["er_visit", "nebulizer", "observation"], "pa_addons": ["inpatient_stay"], "excluded_addons": ["home_nursing"],
		"child_ok": true, "adult_ok": false, "chronic": false, "fatal": true, "history_label": ""},
	{"id": "acl_tear", "label": "Torn ACL, right knee", "condition": "knee_injury", "priority": 1,
		"procs": ["office_visit", "mri_knee", "acl_surgery"], "pa_addons": ["rehab"], "excluded_addons": ["prp_injection", "massage"],
		"child_ok": false, "adult_ok": true, "chronic": true, "fatal": false, "history_label": "Right knee injury"},
	{"id": "gallstones", "label": "Gallbladder attack", "condition": "gallbladder", "priority": 1,
		"procs": ["er_visit", "ultrasound", "gallbladder"], "pa_addons": ["inpatient_stay"], "excluded_addons": [],
		"child_ok": false, "adult_ok": true, "chronic": false, "fatal": true, "history_label": ""},
	{"id": "dka", "label": "Diabetic ketoacidosis", "condition": "diabetes", "priority": 1,
		"procs": ["er_visit", "iv_fluids", "insulin", "blood_panel"], "pa_addons": ["icu_stay"], "excluded_addons": ["glucose_monitor"],
		"child_ok": true, "adult_ok": true, "chronic": true, "fatal": true, "history_label": "Type 1 diabetes"},
	{"id": "concussion", "label": "Concussion", "condition": "head_injury", "priority": 1,
		"procs": ["er_visit", "ct_head"], "pa_addons": ["mri_brain"], "excluded_addons": ["home_nursing"],
		"child_ok": true, "adult_ok": true, "chronic": false, "fatal": true, "history_label": ""},
	{"id": "kidney_stone", "label": "Kidney stone", "condition": "kidney_stone", "priority": 1,
		"procs": ["er_visit", "ct_abdomen", "iv_fluids"], "pa_addons": ["inpatient_stay"], "excluded_addons": ["acupuncture"],
		"child_ok": false, "adult_ok": true, "chronic": false, "fatal": false, "history_label": ""},
	{"id": "depression", "label": "Major depressive episode", "condition": "depression", "priority": 1,
		"procs": ["psych_eval", "antidepressant", "therapy_sessions"], "pa_addons": ["tms"], "excluded_addons": ["residential_mh"],
		"child_ok": false, "adult_ok": true, "chronic": true, "fatal": false, "history_label": "Depression"},
	{"id": "hip_fx", "label": "Fracture, hip", "condition": "hip_injury", "priority": 1,
		"procs": ["er_visit", "xray_hip", "hip_replacement"], "pa_addons": ["rehab"], "excluded_addons": ["home_nursing"],
		"child_ok": false, "adult_ok": true, "chronic": false, "fatal": true, "history_label": ""},
	{"id": "afib", "label": "Atrial fibrillation", "condition": "heart", "priority": 1,
		"procs": ["er_visit", "ecg", "observation"], "pa_addons": ["echo", "cardiac_cath"], "excluded_addons": ["home_nursing"],
		"child_ok": false, "adult_ok": true, "chronic": true, "fatal": true, "history_label": "Atrial flutter"},
	# CRITICAL
	{"id": "heart_attack", "label": "Heart attack", "condition": "heart", "priority": 2,
		"procs": ["er_visit", "ecg", "cardiac_cath", "stent"], "pa_addons": ["icu_stay"], "excluded_addons": ["air_ambulance"],
		"child_ok": false, "adult_ok": true, "chronic": true, "fatal": true, "history_label": "Heart disease"},
	{"id": "stroke", "label": "Stroke", "condition": "stroke", "priority": 2,
		"procs": ["er_visit", "ct_head", "stroke_tpa"], "pa_addons": ["icu_stay", "rehab"], "excluded_addons": ["air_ambulance", "home_nursing"],
		"child_ok": false, "adult_ok": true, "chronic": false, "fatal": true, "history_label": ""},
	{"id": "breast_cancer", "label": "Breast cancer, stage II", "condition": "breast_cancer", "priority": 2,
		"procs": ["oncology_consult", "biopsy", "chemo"], "pa_addons": ["radiation", "ct_chest"], "excluded_addons": ["proton_beam", "immunotherapy_exp"],
		"child_ok": false, "adult_ok": true, "chronic": true, "fatal": true, "history_label": "Abnormal breast scan"},
	{"id": "colon_cancer", "label": "Colon cancer, stage III", "condition": "colon_cancer", "priority": 2,
		"procs": ["oncology_consult", "ct_abdomen", "chemo"], "pa_addons": ["radiation"], "excluded_addons": ["immunotherapy_exp", "proton_beam"],
		"child_ok": false, "adult_ok": true, "chronic": true, "fatal": true, "history_label": "Colon polyps"},
	{"id": "leukemia", "label": "Acute leukemia", "condition": "leukemia", "priority": 2,
		"procs": ["oncology_consult", "blood_panel", "chemo"], "pa_addons": ["bone_marrow_biopsy"], "excluded_addons": ["gene_therapy"],
		"child_ok": true, "adult_ok": true, "chronic": true, "fatal": true, "history_label": "Leukemia (suspected)"},
	{"id": "lymphoma", "label": "Lymphoma", "condition": "lymphoma", "priority": 2,
		"procs": ["oncology_consult", "biopsy", "chemo"], "pa_addons": ["radiation"], "excluded_addons": ["proton_beam", "gene_therapy"],
		"child_ok": true, "adult_ok": true, "chronic": true, "fatal": true, "history_label": "Swollen lymph nodes"},
	{"id": "sepsis", "label": "Sepsis", "condition": "sepsis", "priority": 2,
		"procs": ["er_visit", "blood_panel", "iv_fluids", "icu_stay"], "pa_addons": [], "excluded_addons": ["air_ambulance"],
		"child_ok": true, "adult_ok": true, "chronic": false, "fatal": true, "history_label": ""},
	{"id": "kidney_failure", "label": "Kidney failure", "condition": "kidney_disease", "priority": 2,
		"procs": ["office_visit", "blood_panel", "dialysis"], "pa_addons": [], "excluded_addons": ["home_nursing"],
		"child_ok": false, "adult_ok": true, "chronic": true, "fatal": true, "history_label": "Chronic kidney disease"},
	# SCRIPTED ONLY (never drawn at random)
	{"id": "pregnancy", "label": "Pregnancy complications", "condition": "pregnancy", "priority": 1,
		"procs": ["prenatal_visit", "ob_ultrasound", "fetal_monitoring", "observation"], "pa_addons": ["inpatient_stay"], "excluded_addons": [],
		"child_ok": false, "adult_ok": false, "chronic": true, "fatal": true, "history_label": "Pregnancy (confirmed)"},
	{"id": "hypertensive_crisis", "label": "Hypertensive crisis", "condition": "hypertension", "priority": 2,
		"procs": ["er_visit", "ct_head", "echo", "icu_stay", "cardiac_cath"], "pa_addons": [], "excluded_addons": [],
		"child_ok": false, "adult_ok": false, "chronic": true, "fatal": true, "history_label": "Hypertension (pre-employment physical)"},
]

## Eight in network. The Network Directory lists exactly these.
const PROVIDERS_IN: PackedStringArray = [
	"Riverside General Hospital",
	"St. Agnes Medical Center",
	"Northgate Family Clinic",
	"Harborview Urgent Care",
	"Mercer County Hospital",
	"Lakeside Orthopedics",
	"Westbrook Cancer Institute",
	"Elm Street Pediatrics",
]

## Six out of network, three of them near-misses of in-network names.
const PROVIDERS_OUT: PackedStringArray = [
	"Riverside Medical Center",
	"St. Agnes Specialty Hospital",
	"Northgate Family Practice",
	"Harbor Point Medical Center",
	"University Children's Hospital",
	"Eastside Emergency Physicians",
]

const PLANS: PackedStringArray = ["Bronze Essential", "Bronze Saver", "Silver Select", "Silver Plus", "Gold Advantage"]

## History entries that never collide with any diagnosis's condition and are not
## clinically related to any of them either, so "the claimed condition under
## another name" (R-05) is always decidable. `min_age` (years) keeps a toddler's
## history free of wisdom teeth and bunions.
const FILLER_HISTORY: Array[Dictionary] = [
	{"label": "Chickenpox", "condition": "hx_chickenpox", "min_age": 1},
	{"label": "Wisdom teeth removed", "condition": "hx_teeth", "min_age": 17},
	{"label": "Food poisoning", "condition": "hx_food", "min_age": 2},
	{"label": "Vision correction", "condition": "hx_vision", "min_age": 8},
	{"label": "Shingles", "condition": "hx_shingles", "min_age": 20},
	{"label": "Tooth extraction", "condition": "hx_extraction", "min_age": 6},
	{"label": "Ingrown toenail", "condition": "hx_toenail", "min_age": 6},
	{"label": "Bunion", "condition": "hx_bunion", "min_age": 14},
	{"label": "Tetanus booster", "condition": "hx_tetanus", "min_age": 4},
	{"label": "Dental crown", "condition": "hx_crown", "min_age": 5},
	{"label": "Plantar wart", "condition": "hx_wart", "min_age": 4},
	{"label": "Ganglion cyst", "condition": "hx_ganglion", "min_age": 12},
]


static func diagnosis(id: String) -> Dictionary:
	for dx in DIAGNOSES:
		if dx["id"] == id:
			return dx
	return {}


static func pa_labels() -> PackedStringArray:
	var labels: PackedStringArray = []
	for id: String in PROCEDURES:
		if PROCEDURES[id]["pa"]:
			labels.append(PROCEDURES[id]["label"])
	labels.sort()
	return labels


static func excluded_labels() -> PackedStringArray:
	var labels: PackedStringArray = []
	for id: String in PROCEDURES:
		if PROCEDURES[id]["excluded"]:
			labels.append(PROCEDURES[id]["label"])
	labels.sort()
	return labels


static func is_in_network(provider: String) -> bool:
	return PROVIDERS_IN.has(provider)
