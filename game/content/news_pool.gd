class_name NewsPool
## Text pools for the morning paper, the employment agreement and office flavor.

## Lead stories when no event or scripted story takes the front page.
## Indexed by discontent band: 0 = under 30%, 1 = 30-54%, 2 = 55-79%, 3 = 80%+. At least 4 per band.
const LEAD_BY_BAND: Array = [
	[ # 0: under 30%
		{
			"headline": "Benevolence Mutual posts record quarter",
			"sub": "BMH shares close at an all-time high. The insurer credits \"disciplined claims management.\"",
		},
		{
			"headline": "Insurers say premiums will rise 'modestly' this year",
			"sub": "An industry group cites the rising cost of care. The average family plan will go up 11 percent.",
		},
		{
			"headline": "Benevolence Mutual staff 'highly engaged,' survey finds",
			"sub": "Ninety-seven percent of adjusters report a strong sense of purpose. The survey was mandatory.",
		},
		{
			"headline": "Hospital parking rates rise for third straight year",
			"sub": "Downtown hospital garages now charge $6 an hour. Hospitals say the revenue supports patient care.",
		},
		{
			"headline": "Benevolence Mutual unveils new headquarters lobby",
			"sub": "The atrium features a three-story waterfall and the words \"We care.\" in brushed steel.",
		},
	],
	[ # 1: 30-54%
		{
			"headline": "Complaints against insurers up sharply, state says",
			"sub": "Benevolence Mutual says the increase reflects \"stronger member engagement.\"",
		},
		{
			"headline": "Patients line up before dawn outside claims office",
			"sub": "Some brought folding chairs. Benevolence Mutual has installed a second ticket dispenser.",
		},
		{
			"headline": "Readers write in about denied claims",
			"sub": "The Ledger received more than 300 letters this week. A selection runs on page 6.",
		},
		{
			"headline": "Benevolence Mutual: 'Every claim gets a fair look'",
			"sub": "The company declined to say how long a fair look takes.",
		},
		{
			"headline": "Medical crowdfunding hits record in the city",
			"sub": "Residents raised $4.1 million online for medical bills last year. Most campaigns fell short of their goal.",
		},
	],
	[ # 2: 55-79%
		{
			"headline": "Former adjusters describe denial quotas",
			"sub": "Benevolence Mutual calls the accounts \"anecdotal\" and says it sets \"performance targets,\" not quotas.",
		},
		{
			"headline": "Lawmakers demand answers from Benevolence Mutual",
			"sub": "The insurer says it welcomes the chance to share its story of care. It has retained outside counsel.",
		},
		{
			"headline": "ER doctors say insurer denials are delaying care",
			"sub": "Benevolence Mutual calls the delays \"a natural part of a thorough process.\"",
		},
		{
			"headline": "Vigil held downtown for patients denied coverage",
			"sub": "Several hundred people attended. Benevolence Mutual sent a wreath and a prepared statement.",
		},
		{
			"headline": "Benevolence Mutual hires crisis communications firm",
			"sub": "The firm's first recommendation is a new slogan. Focus groups are underway.",
		},
	],
	[ # 3: 80%+
		{
			"headline": "Thousands march on Benevolence Mutual headquarters",
			"sub": "Police closed four blocks downtown. Employees have been asked to use the loading dock until further notice.",
		},
		{
			"headline": "Benevolence Mutual board approves retention bonuses",
			"sub": "A filing says the bonuses will keep executives focused \"during a period of heightened public interest.\"",
		},
		{
			"headline": "Doctors urge patients to keep every piece of paper",
			"sub": "\"Every page, every receipt, every letter,\" one physician said. \"Get all of it in writing.\"",
		},
		{
			"headline": "Benevolence Mutual: 'We care' remains our promise",
			"sub": "The company's full-page statement runs on page 3. The footnote also runs on page 3, in smaller type.",
		},
		{
			"headline": "Hospitals report surge in uninsured patients",
			"sub": "Many say they dropped their Benevolence Mutual plans. The company describes this as \"normal churn.\"",
		},
	],
]

## Front pages for threshold events, keyed by threshold.
const EVENT_LEADS: Dictionary = {
	30: {
		"headline": "Protesters gather outside Benevolence Mutual HQ",
		"sub": "Hundreds rallied outside the downtown tower. The company called it \"a vibrant expression of feedback.\"",
	},
	55: {
		"headline": "Paid to say no: inside Benevolence Mutual",
		"sub": "A Ledger investigation finds adjusters earn commission on every denial. State regulators announce an audit.",
	},
	80: {
		"headline": "Congress calls Benevolence Mutual to testify",
		"sub": "A hearing on claim denials is set for next month. The company says it looks forward to \"clearing the air.\"",
	},
}

## Small filler items about health care costs, the company, the city. At least 20.
const FLAVOR: Array = [
	{
		"headline": "Ambulance base fee rises to $1,850",
		"body": "The city's private ambulance operator also raised its mileage charge to $34 a mile. A spokesperson encouraged residents to check their coverage before calling.",
	},
	{
		"headline": "Benevolence Mutual sponsors charity 5K",
		"body": "Proceeds benefit the Benevolence Mutual Foundation. All runners must sign a waiver. Injuries sustained on the course are not covered.",
	},
	{
		"headline": "Rescue inhaler prices climb again",
		"body": "The most common rescue inhaler now costs $68 at city pharmacies, up from $52 last spring. The manufacturer cited \"continued innovation.\"",
	},
	{
		"headline": "Study: half of collections calls are medical debt",
		"body": "Half of all collections calls in the city involve medical bills, a university study found. Most of the people being called had health insurance.",
	},
	{
		"headline": "Adjuster wins company chili cook-off",
		"body": "Adjuster #2209 took first prize at Benevolence Mutual's annual cook-off. The prize, a half day off, will be scheduled at a later date.",
	},
	{
		"headline": "Insurer hold times average 94 minutes",
		"body": "A consumer group timed 400 calls to health insurers. The longest lasted six hours and ended when the line went dead.",
	},
	{
		"headline": "East Side's last 24-hour pharmacy to close",
		"body": "The pharmacy closes at the end of the month. The nearest alternative is forty minutes away by bus. The owners cited rising costs.",
	},
	{
		"headline": "Benevolence Mutual launches wellness app",
		"body": "The free app tracks steps, sleep and heart rate. Members who share their data may be eligible for premium adjustments, the company said.",
	},
	{
		"headline": "Hospital price list runs 4,000 pages",
		"body": "A downtown hospital has posted its prices online, as the law requires. One aspirin is listed at $22. A box of tissues appears as a \"mucus recovery system,\" $39.",
	},
	{
		"headline": "Ballpark to be renamed Benevolence Mutual Field",
		"body": "The city's minor league ballpark takes its new name next season. Terms were not disclosed. Seats behind home plate will be designated \"in-network.\"",
	},
	{
		"headline": "Community clinic booking new patients for July",
		"body": "The East Side clinic sees walk-ins on Tuesdays, first come, first served. Staff say the line usually starts forming around 5 a.m.",
	},
	{
		"headline": "Benevolence Mutual CEO pay disclosed",
		"body": "The insurer's chief executive earned $31.6 million last year, a filing shows, including a bonus tied to lowering the share of premiums spent on care.",
	},
	{
		"headline": "Bus route to county hospital cut",
		"body": "Budget cuts end the No. 14, the only direct route from the East Side to the county hospital. Riders are advised to take the No. 9 and transfer twice.",
	},
	{
		"headline": "Survey: 1 in 4 adults skipped care over cost",
		"body": "One in four adults in the city delayed or skipped medical care last year because of cost, a health department survey found. One in ten rationed medication.",
	},
	{
		"headline": "Insurer honored for member experience",
		"body": "Benevolence Mutual received a Member Experience Award from the Council for Coverage Excellence, an industry group it helps fund.",
	},
	{
		"headline": "Free blood pressure checks at the library",
		"body": "The East Side branch library offers free screenings Saturday from 9 a.m. to noon. Volunteers will not be able to help with insurance paperwork.",
	},
	{
		"headline": "Paramedics: don't wait to call",
		"body": "City paramedics say more residents are waiting too long to call for help because they fear the bill. \"Call anyway,\" one paramedic said. \"Argue about it later.\"",
	},
	{
		"headline": "BMH shareholder meeting moves online",
		"body": "Benevolence Mutual will hold its annual shareholder meeting online this year, citing scheduling. Questions must be submitted in writing 30 days in advance.",
	},
	{
		"headline": "Insurer presents check to children's hospital",
		"body": "Benevolence Mutual presented a $50,000 check at a ceremony this week. The oversized check was later listed in company filings as a marketing expense.",
	},
	{
		"headline": "Denial letter redesign wins regional award",
		"body": "Benevolence Mutual's new denial letter was honored for \"clarity and warmth.\" The letter now opens with a drawing of a smiling sun.",
	},
	{
		"headline": "Bake sale raises $640 for neighbor's treatment",
		"body": "Residents of an East Side apartment building held a bake sale to help a neighbor pay for chemotherapy. They need $38,000 more. The lemon bars sold out first.",
	},
	{
		"headline": "Member handbook grows by 41 pages",
		"body": "Benevolence Mutual's updated member handbook adds 41 pages of exclusions. The glossary has been removed. The company said it \"was not being used.\"",
	},
	{
		"headline": "Nurses report record overtime",
		"body": "Nurses at two downtown hospitals averaged 14 hours of overtime a week last month, their union says. Hospital management describes staffing as \"adequate.\"",
	},
	{
		"headline": "Weather: gray, chance of rain",
		"body": "Highs in the low 40s. Residents with breathing problems are advised to stay indoors if they can and to keep their inhalers close.",
	},
	{
		"headline": "Dental school offers $15 cleanings",
		"body": "Students at the dental school will clean teeth under supervision for $15. Saturday's appointments filled within an hour of opening.",
	},
	{
		"headline": "Funeral costs up 9 percent",
		"body": "The average funeral in the city now costs $8,300, according to a trade association. Cremation remains the most popular option.",
	},
]

## Runs on day 6, the morning before DenyBot reaches the desk, in place of a FLAVOR item.
const DENYBOT_PILOT := {
	"headline": "Benevolence Mutual tests automated claim review",
	"body": "The insurer is piloting software that can decide a claim in under a second. A spokesperson said the system, DenyBot, will \"free adjusters to focus on what matters.\"",
}

## Letters to the editor from patients processed the day before, by the rule
## their denial cited ("" for a denial with no reason). {name} is the writer.
## Plain facts in the patient's voice; nobody moralizes.
const EDITOR_LETTERS: Dictionary = {
	"R-01": "To the editor: Benevolence Mutual says my coverage lapsed. I was late on one payment. One. - {name}",
	"R-02": "To the editor: I went to the hospital my doctor sent me to. Benevolence Mutual says it is out of network. Nobody at the hospital mentioned it. - {name}",
	"R-03": "To the editor: My claim was denied because a form I never filled out has a typo on it. I have called the hospital three times. - {name}",
	"R-04": "To the editor: My claim was denied for lack of prior authorization. Nobody told me there was anything to authorize. - {name}",
	"R-05": "To the editor: Benevolence Mutual found my condition in records from before I enrolled. They call it pre-existing. It is why I enrolled. - {name}",
	"R-06": "To the editor: My doctor ordered the treatment. Benevolence Mutual says it is on their list of exclusions. I asked to see the list. - {name}",
	"R-07": "To the editor: My denial letter gives the reason as proprietary. I called to ask what that means. They could not say. - {name}",
	"": "To the editor: Benevolence Mutual denied my claim. The letter does not give a reason. I have asked for one twice. - {name}",
}
## From a patient whose claim was approved.
const EDITOR_THANKS := "To the editor: I want to thank the person at Desk 11. I never got a name. - {name}"

## Obituaries for patients who died after a denial. Placeholders: {name} full name, {age},
## {weekday} like "Tuesday", {condition} the diagnosis in lowercase like "fracture, left wrist".
## At least 6. The insurer is never named; the reader connects it.
## Every template fits any age from 1 to 90, and {condition} always ends its sentence.
const OBITUARY_TEMPLATES: Array[String] = [
	"{name}, {age}, died {weekday} at home. The cause was listed as complications of {condition}. Treatment had been recommended weeks earlier. In lieu of flowers, the family asks for help with medical bills.",
	"{name}, {age}, of the East Side, died {weekday}. Cause of death: {condition}. Friends remember a laugh that carried down the whole block. The family had been told to wait. Services will be private.",
	"{name}, {age}, died {weekday}. Doctors had scheduled treatment, pending paperwork. Cause of death: {condition}. A collection for funeral costs is being taken at the corner market.",
	"{name}, {age}, a lifelong resident of the city, died {weekday} while awaiting a decision on care. The cause was {condition}. Survived by family and an outstanding balance.",
	"{name}, {age}, died {weekday} at the county hospital, two days after being sent home. Listed cause: {condition}. Visitation is open to all. Donations to the family's fundraiser are welcome.",
	"{name}, {age}, died {weekday}. The cause was untreated {condition}. Always the first one up in the morning, {name} will be missed. The family thanks the nurses on the fourth floor.",
	"{name}, {age}, died {weekday}. The family had filled out every form, gathered every record and gone in person. Cause of death: {condition}. A memorial will be held at the community center.",
	"{name}, {age}, passed away {weekday} after a short illness. Cause of death: {condition}. {name} was learning the piano and practiced every night. The family is still sorting out the bills.",
]

## Stock blurbs for BMH. {change} is a number like "2.4". At least 4 each.
const STOCK_UP: Array[String] = [
	"BMH rose {change}% after analysts praised the insurer's \"claims discipline.\"",
	"Benevolence Mutual (BMH) gained {change}% on lower-than-expected medical costs.",
	"BMH climbed {change}%. One analyst upgraded the stock, citing \"a culture of rigor.\"",
	"Shares of BMH rose {change}% as the company reaffirmed its earnings outlook.",
	"BMH up {change}%. Investors cheered a decline in the insurer's payout ratio.",
]

const STOCK_DOWN: Array[String] = [
	"BMH fell {change}% on higher-than-expected claims costs.",
	"Shares of Benevolence Mutual slipped {change}% as payouts rose. Management promised \"corrective measures.\"",
	"BMH down {change}%. An analyst warned of \"elevated generosity\" at the claims level.",
	"BMH lost {change}% after the insurer paid more claims than forecast.",
	"BMH dipped {change}%. The company says it is \"reviewing approval patterns.\"",
]

## The employment agreement's fine print, shown on the hiring screen where the player signs.
const AGREEMENT: PackedStringArray = [
	"1. EMPLOYMENT. Benevolence Mutual (\"the Company\") employs the undersigned (\"the Adjuster\") at will. Either party may end the arrangement at any time, for any reason or for no reason. The Company does not expect to need a reason.",
	"2. SCHEDULE. Benevolence Mutual operates seven days a week. Illness doesn't take weekends off, and neither do we. A shift ends when the last patient of the day has been processed. Holidays are observed at the Company's discretion.",
	"3. COMPENSATION. The Adjuster receives a daily base wage plus a commission on each claim resolved in the Company's favor. The cost of each approved claim is shared with the Adjuster through a payroll adjustment. Compliance reviews are billed at cost.",
	"4. PERFORMANCE. Performance is measured against targets set by Claims Integrity. Targets may change at any time to reflect business needs. Meeting a target today does not mean the target will be the same tomorrow.",
	"5. BENEFITS. The Adjuster and dependents are enrolled in the Company's own health plan, subject to standard exclusions, limitations, waiting periods, network requirements and prior authorization. Conditions noted at the pre-employment physical are pre-existing.",
	"6. DECISIONS. Every claim decision is made by the Adjuster alone. The Company provides guidance, targets and tools but does not make decisions. The Adjuster accepts sole responsibility for each stamp.",
	"7. CONDUCT. The Adjuster will not disparage the Company, its officers, its products, its policies or its determinations, in public or in private, during employment or after. The Company may comment on the Adjuster as needed.",
	"8. ACKNOWLEDGMENT. By signing below, the Adjuster confirms having read and understood this agreement, or having chosen not to. This agreement binds the Adjuster's heirs, assigns and estate.",
]

## Corporate slogans for the poster behind the booth window. At least 8, 40 characters or fewer.
const SLOGANS: PackedStringArray = [
	"We care.*",
	"Your health is our business.",
	"Care, carefully.",
	"Coverage you can count on.*",
	"Benevolence. It's in our name.",
	"Here when you need us.*",
	"Accuracy is a form of compassion.",
	"Every dollar saved is a dollar earned.",
	"Healthy members. Healthy margins.",
	"Integrity. Efficiency. Benevolence.",
	"No claim too small to review.",
	"Thoroughness is kindness.",
]


## A uniform random element of pool, or null if it is empty. Dictionaries and arrays come back
## as deep copies, because the pools are constants and read-only.
static func pick(pool: Array, rng: RandomNumberGenerator) -> Variant:
	if pool.is_empty():
		return null
	var item: Variant = pool[rng.randi_range(0, pool.size() - 1)]
	if item is Dictionary:
		var dict: Dictionary = item
		return dict.duplicate(true)
	if item is Array:
		var list: Array = item
		return list.duplicate(true)
	return item
