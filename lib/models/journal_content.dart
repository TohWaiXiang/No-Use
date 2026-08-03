// LUNA Health — Period Education Knowledge Hub content.
// Evidence review date: 27 July 2026. Educational content only — not a diagnosis.
class JournalQuestion {
  final String id;
  final String question;
  final List<String> paragraphs;

  const JournalQuestion({
    required this.id,
    required this.question,
    required this.paragraphs,
  });
}

class JournalSection {
  final String id;
  final String title;
  final List<JournalQuestion> questions;

  const JournalSection({
    required this.id,
    required this.title,
    required this.questions,
  });
}

class JournalGroup {
  final String id;
  final String title;
  final List<JournalSection> sections;

  const JournalGroup({
    required this.id,
    required this.title,
    required this.sections,
  });
}

const String journalMedicalNotice =
    "This hub provides general health education. It does not diagnose a condition, replace a qualified healthcare professional, or confirm ovulation, pregnancy, fertility, PCOS, menopause, or hormone levels. Cycle and fertile-window predictions must be treated as estimates.";

const String journalReviewDate = "Evidence review date: 27 July 2026";

const List<String> journalUrgentSigns = [
  "Vaginal bleeding soaks through a pad or tampon every hour for two to three consecutive hours.",
  "Bleeding occurs with fainting, marked dizziness, shortness of breath, chest pain, or severe weakness.",
  "A missed period is followed by unusual bleeding and abdominal or pelvic pain.",
  "Pelvic pain is sudden, severe, worsening, or accompanied by fever, repeated vomiting, pregnancy, or possible pregnancy.",
  "Bleeding occurs during pregnancy and is heavy or accompanied by pain or dizziness.",
  "Emotional symptoms include thoughts of self-harm or suicide.",
];

const List<JournalGroup> journalGroups = [
  JournalGroup(
    id: "A",
    title: "Period Foundations",
    sections: [
      JournalSection(
        id: "1",
        title: "Period 101",
        questions: [
          JournalQuestion(
            id: "1.1",
            question: "What is a period?",
            paragraphs: [
              "A period is the bleeding that occurs when the uterus sheds its lining after pregnancy has not occurred.",
              "Day 1 of bleeding is Day 1 of a new menstrual cycle. Menstrual fluid contains blood, mucus, and tissue from the uterine lining. A period often lasts about two to seven days, but personal patterns vary. The first days are commonly heavier, while blood may appear darker or brown near the end because it has taken longer to leave the uterus [1, 4].",
            ],
          ),
          JournalQuestion(
            id: "1.2",
            question: "Spotting vs. a period: What is the difference?",
            paragraphs: [
              "A period is the expected menstrual bleed that begins a cycle, while spotting is a small amount of bleeding outside the expected period.",
              "Spotting may look pink, red, or brown and may only be visible when wiping. Possible causes include hormonal contraception, hormonal changes, pregnancy, infection, fibroids, or polyps. An app cannot determine the cause. Repeated bleeding between periods, bleeding after sex, bleeding during pregnancy, or bleeding after menopause should be medically assessed. A missed period followed by bleeding and pelvic pain requires urgent evaluation [10].",
            ],
          ),
          JournalQuestion(
            id: "1.3",
            question: "How does the menstrual cycle work?",
            paragraphs: [
              "Hormones coordinate changes in the ovaries and uterus to prepare the body for a possible pregnancy.",
              "During the follicular phase, ovarian follicles develop and oestrogen helps rebuild the uterine lining. Ovulation is the release of an egg. During the luteal phase, progesterone supports the lining. If pregnancy does not occur, oestrogen and progesterone fall, the lining sheds, and another period begins. A 28-day cycle is only an example; cycle length and ovulation timing naturally vary [1, 2].",
            ],
          ),
          JournalQuestion(
            id: "1.4",
            question: "What do period-blood colours and clots mean?",
            paragraphs: [
              "Bright red, dark red, pink, and brown blood can all occur during a period. Bright red usually reflects newer blood, while brown blood has taken longer to leave the uterus. Small clots may occur on heavier days.",
              "Arrange medical care if clots are repeatedly large, bleeding is much heavier than usual, bleeding lasts longer than seven days, or the person experiences dizziness, severe tiredness, weakness, or shortness of breath. Colour alone cannot diagnose a condition [4, 18].",
            ],
          ),
        ],
      ),
      JournalSection(
        id: "2",
        title: "First Period and Teen Support",
        questions: [
          JournalQuestion(
            id: "2.1",
            question: "When does the first period usually begin?",
            paragraphs: [
              "Most first periods begin around ages 12–13, commonly about two to three years after breast development starts. Earlier or later development can still be healthy because puberty follows an individual timeline.",
              "Medical assessment is recommended when puberty signs begin before age 8, when no puberty signs are present by about age 13, or when a first period has not occurred by age 15 or approximately three years after breast development began [3, 36].",
            ],
          ),
          JournalQuestion(
            id: "2.2",
            question: "First-period guide: What should I do?",
            paragraphs: [
              "Stay calm, place a pad or period underwear securely, and record the date because it becomes Day 1 of the cycle. Ask a trusted adult, school nurse, pharmacist, or healthcare professional for help if needed. Carry a spare product and underwear.",
              "Early cycles can be unpredictable while the hormone system matures. A first period may be light, short, brown, or irregular and does not need to look exactly like a friend's period [3, 4].",
            ],
          ),
          JournalQuestion(
            id: "2.3",
            question: "My period started earlier than my friends. Is that normal?",
            paragraphs: [
              "Often, yes. Genetics, development, health, and environmental factors influence puberty timing. Starting earlier does not mean someone is emotionally older, sexually active, or unhealthy.",
              "The important comparison is with the person's own development, not with classmates. A clinician should assess puberty that begins unusually early, but the conversation should be supportive and free from shame [3, 6].",
            ],
          ),
          JournalQuestion(
            id: "2.4",
            question: "How can I prepare for periods at school?",
            paragraphs: [
              "Keep a small kit containing two period products, spare underwear, tissues, and a disposal bag. Learn where school toilets and bins are located and identify a trusted teacher, nurse, or friend. If a leak occurs, ask for help and rinse fabric with cold water when possible.",
              "LUNA Health should allow discreet notification text and a hidden-content setting. Research shows that better menstrual-health literacy improves confidence, self-care, and health decision-making among adolescents [6].",
            ],
          ),
        ],
      ),
      JournalSection(
        id: "3",
        title: "Period Products and Hygiene",
        questions: [
          JournalQuestion(
            id: "3.1",
            question: "Which period product is right for me?",
            paragraphs: [
              "The best product is safe, comfortable, affordable, available, and suitable for the person's flow and activities.",
              "- Pads: External and easy to learn.",
              "- Reusable pads: Washable and may reduce long-term cost and waste.",
              "- Period underwear: Worn like ordinary underwear.",
              "- Tampons: Internal absorbent products that may suit sport and swimming.",
              "- Menstrual cups: Reusable internal products that collect blood.",
              "It is reasonable to try different products or combine products on heavy days. Menstrual cups are supported as a generally safe and acceptable option when used correctly [4, 5].",
            ],
          ),
          JournalQuestion(
            id: "3.2",
            question: "How should pads and period underwear be used?",
            paragraphs: [
              "Place a pad securely in the centre of the underwear and fold wings underneath if present. Change it when wet, uncomfortable, leaking, or according to the instructions — often around every four to six hours, depending on flow. Longer products may be more suitable for sleep.",
              "Wrap disposable products and place them in a bin rather than flushing them. Wash reusable pads and period underwear according to their instructions and dry them completely [4].",
            ],
          ),
          JournalQuestion(
            id: "3.3",
            question: "Can teenagers use tampons or menstrual cups?",
            paragraphs: [
              "Yes, if they feel comfortable, can follow the instructions, and can remove the product safely. Start with an appropriate size or low tampon absorbency. A correctly inserted product should not cause ongoing pain.",
              "Tampons cannot pass through the cervix and become lost inside the body. Menstrual cups require the user to release the seal before removal. Internal products do not determine \"virginity,\" which is a social concept rather than a medical diagnosis [4, 5, 39].",
            ],
          ),
          JournalQuestion(
            id: "3.4",
            question: "What is toxic shock syndrome?",
            paragraphs: [
              "Toxic shock syndrome (TSS) is a rare but serious illness that can occur with tampon or menstrual-cup use, although it can also result from other infections. Use clean hands, follow product instructions, use the lowest tampon absorbency needed, and never leave a tampon in for more than eight hours.",
              "Remove the product and seek urgent care for sudden fever, vomiting or diarrhoea, dizziness, confusion, severe muscle pain, or a widespread rash [19].",
            ],
          ),
          JournalQuestion(
            id: "3.5",
            question: "What is healthy period hygiene?",
            paragraphs: [
              "Wash hands before and after changing products. Clean the vulva gently with water or a mild unscented cleanser, but do not clean inside the vagina or douche. The vagina has its own protective environment, and fragranced washes or inserted cleansing products may cause irritation.",
              "A mild menstrual smell can be normal. A strong new odour with unusual discharge, itching, burning, fever, or pelvic pain should be medically assessed [28, 29].",
            ],
          ),
        ],
      ),
      JournalSection(
        id: "4",
        title: "Know Your Cycle",
        questions: [
          JournalQuestion(
            id: "4.1",
            question: "What are the four commonly described cycle stages?",
            paragraphs: [
              "- Menstruation: The uterine lining sheds and bleeding begins.",
              "- Follicular phase: Follicles develop and oestrogen helps rebuild the lining.",
              "- Ovulation: An ovary releases an egg.",
              "- Luteal phase: Progesterone supports the lining after ovulation.",
              "These stages are educational labels. Menstruation is biologically part of the broader follicular phase, and individual bodies do not follow identical day numbers [2].",
            ],
          ),
          JournalQuestion(
            id: "4.2",
            question: "How are ovulation and periods connected?",
            paragraphs: [
              "After ovulation, the emptied follicle produces progesterone. If pregnancy does not occur, progesterone and oestrogen fall and menstrual bleeding begins. Ovulation often occurs roughly 10–16 days before the next period, not automatically on Day 14.",
              "Bleeding can also happen in a cycle without ovulation, called an anovulatory cycle. Therefore, a period-like bleed does not prove that ovulation occurred [2, 4].",
            ],
          ),
          JournalQuestion(
            id: "4.3",
            question: "What signs may occur around ovulation?",
            paragraphs: [
              "Some people notice clearer, wetter, or more slippery cervical mucus; a mild one-sided ache; increased sexual desire; or a small temperature rise after ovulation. Others notice no signs.",
              "These observations cannot confirm ovulation individually. Illness, travel, sleep changes, and measurement technique can affect basal temperature. Ovulation-predictor tests may also be difficult to interpret with irregular cycles or PCOS [2, 13].",
            ],
          ),
          JournalQuestion(
            id: "4.4",
            question: "What information should I track?",
            paragraphs: [
              "Record the first and last bleeding day, flow, spotting, pain, mood, sleep, stress, symptoms, contraception, medication, and relevant pregnancy tests. Use consistent descriptions such as light, medium, or heavy.",
              "Tracking may reveal patterns and provide useful evidence for a consultation. It shows association, not proof of cause — for example, stress and a late period occurring together do not prove that stress caused the delay [1].",
            ],
          ),
          JournalQuestion(
            id: "4.5",
            question: "Can a period app accurately predict ovulation?",
            paragraphs: [
              "Period dates can estimate a possible fertile window, but they cannot guarantee when ovulation occurs. Research audits have found that many period apps provide inaccurate or insufficiently evidence-based ovulation information; one study found calendar-app ovulation prediction was no better than 21% [21, 22].",
              "LUNA Health should label fertile dates as estimates and should never describe them as guaranteed \"safe days\" or as a substitute for contraception.",
            ],
          ),
        ],
      ),
      JournalSection(
        id: "5",
        title: "Period Myths and Everyday Life",
        questions: [
          JournalQuestion(
            id: "5.1",
            question: "Can I swim, shower, or exercise during a period?",
            paragraphs: [
              "Yes. Menstruation does not make bathing, swimming, or exercise unsafe. Tampons, cups, and suitable period swimwear can be used for swimming. Gentle movement may reduce cramps for some people, while rest is reasonable when symptoms are strong.",
              "The product should be changed or cleaned according to its instructions after activity [4, 7].",
            ],
          ),
          JournalQuestion(
            id: "5.2",
            question: "Can pregnancy happen during or soon after a period?",
            paragraphs: [
              "Yes, although the likelihood varies. Ovulation can occur earlier than expected, especially with short or irregular cycles, and sperm can survive in the reproductive tract for several days. Bleeding assumed to be a period may also have another cause.",
              "Someone who wishes to avoid pregnancy should use a recognised contraceptive method rather than relying on period timing alone [4, 12].",
            ],
          ),
          JournalQuestion(
            id: "5.3",
            question: "Can a tampon become lost or affect virginity?",
            paragraphs: [
              "A tampon cannot pass through the cervix into the abdomen. It may move higher in the vagina or become difficult to remove, but a healthcare professional can remove it if needed. Seek help if a tampon cannot be removed or may have been left in too long.",
              "Tampon use does not medically determine whether someone is a virgin. A person's hymen appearance also cannot prove sexual activity [4].",
            ],
          ),
          JournalQuestion(
            id: "5.4",
            question: "Do friends' periods really synchronise?",
            paragraphs: [
              "People living or studying together may occasionally have overlapping periods because cycles naturally vary and calendar dates shift. Current evidence does not establish a reliable biological mechanism that forces menstrual cycles to synchronise.",
              "LUNA Health should avoid presenting period synchronisation as a medical fact. Research examining people living in groups found that their cycles did not progressively synchronise [38].",
            ],
          ),
          JournalQuestion(
            id: "5.5",
            question: "Can food stop a period or \"clean\" the uterus?",
            paragraphs: [
              "No particular food can safely stop menstruation or remove \"dirty blood.\" Menstrual blood is normal blood and uterine tissue, not a toxin. Balanced meals and hydration may support comfort, but they do not cure a hormonal or gynaecological condition.",
              "Products claiming to cleanse the uterus, permanently regulate hormones, or guarantee fertility should be treated cautiously [1, 2].",
            ],
          ),
        ],
      ),
    ],
  ),
  JournalGroup(
    id: "B",
    title: "Symptoms and Self-Care",
    sections: [
      JournalSection(
        id: "6",
        title: "Period Cramps",
        questions: [
          JournalQuestion(
            id: "6.1",
            question: "Why do period cramps happen?",
            paragraphs: [
              "Prostaglandins make the uterus contract to shed its lining. This common pain is called primary dysmenorrhoea and usually begins just before or when bleeding starts.",
              "Secondary dysmenorrhoea is caused by another condition, such as endometriosis, adenomyosis, fibroids, or pelvic infection. It is more likely when pain worsens over time, appears outside the period, or occurs with sex, urination, bowel movements, fertility difficulty, or abnormal bleeding [7].",
            ],
          ),
          JournalQuestion(
            id: "6.2",
            question: "What are five evidence-supported ways to manage cramps?",
            paragraphs: [
              "- Apply safe, covered heat to the lower abdomen.",
              "- Try comfortable walking, stretching, or movement.",
              "- Use an appropriate anti-inflammatory medicine if safe, following the label or professional advice.",
              "- Protect rest and sleep.",
              "- Track pain, bleeding, and the response to treatment.",
              "Systematic-review evidence supports heat therapy for primary menstrual pain. Anti-inflammatory medicines are not suitable for everyone, including some people with stomach, kidney, bleeding, allergy, asthma, or pregnancy-related concerns [7, 8].",
            ],
          ),
          JournalQuestion(
            id: "6.3",
            question: "When is period pain not normal?",
            paragraphs: [
              "Arrange medical care when pain repeatedly causes missed school or work, does not improve with appropriate self-care, starts after years of comfortable periods, or occurs with heavy bleeding, fever, pain during sex, bowel or bladder symptoms, or fertility difficulty.",
              "Sudden severe pain, fainting, or pain with a missed period or possible pregnancy requires urgent assessment. Severe pain should not be dismissed simply because periods commonly cause discomfort [7, 24].",
            ],
          ),
        ],
      ),
      JournalSection(
        id: "7",
        title: "PMS and PMDD",
        questions: [
          JournalQuestion(
            id: "7.1",
            question: "What is premenstrual syndrome?",
            paragraphs: [
              "PMS is a recurring group of physical and emotional symptoms that appears after ovulation, before the period, and improves soon after bleeding begins. Symptoms may include bloating, breast tenderness, headache, acne, tiredness, poor sleep, irritability, anxiety, low mood, cravings, or concentration difficulty.",
              "Daily tracking for at least two cycles helps confirm whether symptoms follow a premenstrual pattern [4, 11].",
            ],
          ),
          JournalQuestion(
            id: "7.2",
            question: "What is the difference between PMS and PMDD?",
            paragraphs: [
              "Premenstrual dysphoric disorder (PMDD) is a more severe premenstrual disorder in which mood symptoms significantly affect daily functioning. Possible symptoms include severe irritability, depression, anxiety, mood swings, loss of interest, or feeling overwhelmed.",
              "Diagnosis requires a consistent cycle-related pattern and professional assessment. Thoughts of self-harm or suicide require urgent help [11].",
            ],
          ),
          JournalQuestion(
            id: "7.3",
            question: "How can PMS or PMDD be treated?",
            paragraphs: [
              "Regular activity, adequate sleep, balanced meals, stress-management skills, and reducing personal triggers may help mild symptoms. Evidence-based professional treatments can include cognitive behavioural therapy, selected antidepressants, and certain hormonal contraceptives.",
              "Treatment should be personalised. Supplements may interact with medicines or contain unreliable doses, so they should be discussed with a pharmacist or clinician [11].",
            ],
          ),
          JournalQuestion(
            id: "7.4",
            question: "When should I seek help for premenstrual symptoms?",
            paragraphs: [
              "Seek help when symptoms affect relationships, study, work, sleep, eating, or personal safety; occur throughout the month; or do not improve with self-care. Bring at least two months of symptom records if possible.",
              "A clinician may also consider depression, anxiety, thyroid disease, medication effects, or perimenopause because these can resemble or worsen PMS [11].",
            ],
          ),
        ],
      ),
      JournalSection(
        id: "8",
        title: "Irregular Periods",
        questions: [
          JournalQuestion(
            id: "8.1",
            question: "What is an irregular period?",
            paragraphs: [
              "A period is irregular when cycle timing, duration, or flow repeatedly differs from the person's usual pattern. Many clinical references describe adult cycles of approximately 21–35 days as common, while slightly different evidence-based ranges are also used.",
              "Irregularity is more common in the first few years after the first period and during perimenopause. Patterns across several months are more informative than one unusual cycle [1, 9].",
            ],
          ),
          JournalQuestion(
            id: "8.2",
            question: "What can cause irregular periods?",
            paragraphs: [
              "Possible causes include puberty, perimenopause, pregnancy, breastfeeding, hormonal contraception, major stress, significant weight change, insufficient energy intake, and intense exercise. PCOS, thyroid disorders, high prolactin, chronic illness, and some medicines can also change cycles.",
              "Different causes can produce similar symptoms, so an app cannot make the diagnosis [9, 16].",
            ],
          ),
          JournalQuestion(
            id: "8.3",
            question: "How should I track an irregular cycle?",
            paragraphs: [
              "Record bleeding dates, flow, spotting, pain, contraception, medicine, pregnancy possibility, and relevant symptoms such as acne, facial hair growth, tiredness, hot flushes, nipple discharge, or major weight change.",
              "LUNA Health should reduce confidence in date predictions when the user's cycles vary and explain why the estimated window is wider [1, 9, 21].",
            ],
          ),
          JournalQuestion(
            id: "8.4",
            question: "When should irregular periods be checked?",
            paragraphs: [
              "Arrange medical care if the usual pattern changes and stays changed, periods repeatedly occur less than about 21 days or more than about 35 days apart, bleeding lasts longer than seven days, or there is bleeding between periods or after sex.",
              "Also seek assessment if periods stop for three months after being regular or irregular cycles occur with pregnancy difficulty, major weight change, tiredness, facial hair growth, nipple discharge, headache, or vision change [9, 16].",
            ],
          ),
        ],
      ),
      JournalSection(
        id: "9",
        title: "Heavy Periods and Anaemia",
        questions: [
          JournalQuestion(
            id: "9.1",
            question: "How can I recognise a heavy period?",
            paragraphs: [
              "Possible signs include changing a pad or tampon every one to two hours, frequent leaks, needing two products together, emptying a cup more often than recommended, bleeding longer than seven days, repeatedly passing large clots, or avoiding normal activities because of flow.",
              "How bleeding affects life is clinically important even when an exact blood volume cannot be measured [18, 37].",
            ],
          ),
          JournalQuestion(
            id: "9.2",
            question: "What can cause heavy menstrual bleeding?",
            paragraphs: [
              "Possible causes include anovulatory cycles, fibroids, adenomyosis, endometriosis, PCOS, pelvic infection, thyroid problems, bleeding disorders, some medicines, and changes around puberty or perimenopause. Sometimes no structural cause is found.",
              "Because treatment depends on the cause and pregnancy possibility, heavy bleeding should not be self-diagnosed [20, 37].",
            ],
          ),
          JournalQuestion(
            id: "9.3",
            question: "Can heavy periods cause iron deficiency?",
            paragraphs: [
              "Yes. Repeated blood loss can deplete iron and may lead to iron-deficiency anaemia. Symptoms can include tiredness, weakness, reduced concentration, headache, dizziness, paleness, fast heartbeat, or shortness of breath.",
              "Research identifies heavy menstrual bleeding as a major contributor to iron deficiency and reduced quality of life [17, 34].",
            ],
          ),
          JournalQuestion(
            id: "9.4",
            question: "How are heavy periods assessed and treated?",
            paragraphs: [
              "A clinician may review bleeding history, pregnancy possibility, medicines, and family history and may order a blood count, ferritin, thyroid testing, clotting tests, or ultrasound. Treatment can include anti-inflammatory medicine, tranexamic acid, hormonal treatment, an intrauterine system, iron treatment, or a procedure depending on the cause and reproductive goals.",
              "Iron should not be taken in high doses without appropriate advice or testing [17, 37].",
            ],
          ),
          JournalQuestion(
            id: "9.5",
            question: "When is heavy bleeding an emergency?",
            paragraphs: [
              "Seek urgent care for bleeding that soaks a pad or tampon every hour for two to three hours, especially with dizziness, fainting, breathing difficulty, chest pain, severe weakness, pregnancy, or severe pelvic pain.",
              "LUNA Health should show an urgent-safety prompt when users log this combination of symptoms [18].",
            ],
          ),
        ],
      ),
      JournalSection(
        id: "10",
        title: "Remedies and Whole-Person Wellness",
        questions: [
          JournalQuestion(
            id: "10.1",
            question: "What can safely help common period discomfort?",
            paragraphs: [
              "Covered heat, a warm shower, comfortable movement, adequate sleep, loose clothing, gentle massage, and an appropriate over-the-counter pain reliever can help some people. Medication should follow the label or pharmacist's advice.",
              "Self-care should improve comfort, not hide severe or worsening symptoms [7, 8].",
            ],
          ),
          JournalQuestion(
            id: "10.2",
            question: "Do nutrition and hydration affect period symptoms?",
            paragraphs: [
              "Regular meals and adequate fluid support overall wellbeing, but no single diet \"balances all hormones.\" People with heavy bleeding need enough dietary iron from foods such as meat, fish, beans, lentils, tofu, dark-green vegetables, and fortified foods.",
              "Persistent fatigue or heavy bleeding warrants testing rather than relying only on food or supplements [17].",
            ],
          ),
          JournalQuestion(
            id: "10.3",
            question: "Are herbal remedies and supplements safe?",
            paragraphs: [
              "Not automatically. Supplements may have limited evidence, inconsistent ingredients, or interactions with contraception, antidepressants, blood thinners, and other medicines. Some are unsafe during pregnancy or with liver, kidney, or bleeding conditions.",
              "LUNA Health should not recommend a dose or claim that a supplement \"balances hormones\" without guideline support and clinician review.",
            ],
          ),
          JournalQuestion(
            id: "10.4",
            question: "How are periods connected to sleep and mental wellbeing?",
            paragraphs: [
              "Pain, hormonal changes, stigma, heavy bleeding, and sleep disruption can affect concentration and mood. Tracking can show whether symptoms are mainly premenstrual, occur during painful bleeding, or continue throughout the month.",
              "Persistent anxiety, low mood, disordered eating, or sleep problems deserve support rather than being dismissed as \"just hormones\" [6, 11].",
            ],
          ),
          JournalQuestion(
            id: "10.5",
            question: "Can I exercise during my period?",
            paragraphs: [
              "Yes, if comfortable. Walking, stretching, yoga, swimming, and usual training are generally possible. Exercise may reduce cramps for some people.",
              "However, intense training combined with insufficient energy can contribute to irregular or absent periods and reduced bone health. Repeated missed periods or stress fractures in an active person require assessment [20].",
            ],
          ),
        ],
      ),
    ],
  ),
  JournalGroup(
    id: "C",
    title: "Menstrual and Pelvic Conditions",
    sections: [
      JournalSection(
        id: "11",
        title: "Endometriosis",
        questions: [
          JournalQuestion(
            id: "11.1",
            question: "What is endometriosis?",
            paragraphs: [
              "Endometriosis is a condition in which tissue similar to the uterine lining grows outside the uterus, often around pelvic organs. It can cause inflammation, scarring, pain, and fertility difficulties. Symptoms and disease extent do not always match; a person with limited visible disease can still experience severe pain [23, 24].",
            ],
          ),
          JournalQuestion(
            id: "11.2",
            question: "What are common warning signs?",
            paragraphs: [
              "Possible signs include period pain that stops normal activities, chronic pelvic or lower-back pain, pain during or after sex, pain when urinating or passing stool — especially during periods — heavy bleeding, fatigue, or difficulty becoming pregnant.",
              "These symptoms overlap with other conditions, so professional assessment is required [24].",
            ],
          ),
          JournalQuestion(
            id: "11.3",
            question: "Is severe period pain always endometriosis?",
            paragraphs: [
              "No. Fibroids, adenomyosis, pelvic infection, ovarian conditions, and primary dysmenorrhoea can also cause pain. However, severe or worsening pain should not be normalised.",
              "Tracking the timing, location, severity, bowel or bladder symptoms, and response to pain relief helps a clinician investigate [7, 24].",
            ],
          ),
          JournalQuestion(
            id: "11.4",
            question: "How is endometriosis diagnosed and managed?",
            paragraphs: [
              "Assessment can include symptom history, examination, ultrasound, or MRI. Normal imaging does not always exclude endometriosis. Laparoscopy may be used in selected cases to identify and treat lesions.",
              "Management can include pain medicine, hormonal treatment, surgery, fertility support, and multidisciplinary care based on symptoms and goals [23].",
            ],
          ),
        ],
      ),
      JournalSection(
        id: "12",
        title: "Fibroids and Adenomyosis",
        questions: [
          JournalQuestion(
            id: "12.1",
            question: "What are uterine fibroids?",
            paragraphs: [
              "Fibroids are growths made from muscle and fibrous tissue in or around the uterus. They are almost always non-cancerous. Many cause no symptoms, while others cause heavy or painful periods, pelvic pressure, frequent urination, constipation, or discomfort during sex [25].",
            ],
          ),
          JournalQuestion(
            id: "12.2",
            question: "What is adenomyosis?",
            paragraphs: [
              "Adenomyosis occurs when tissue similar to the uterine lining is present within the muscular wall of the uterus. Possible symptoms include severe cramps, heavy bleeding, pelvic pain, bloating, abdominal heaviness, or pain during sex. Some people have no symptoms [26].",
            ],
          ),
          JournalQuestion(
            id: "12.3",
            question: "How are fibroids and adenomyosis different?",
            paragraphs: [
              "Fibroids are distinct muscular growths, while adenomyosis is lining-like tissue within the uterine muscle. Both can cause heavy bleeding and pain, so symptoms alone may not distinguish them.",
              "An examination and imaging, often ultrasound and sometimes MRI, may help identify the cause [25, 26].",
            ],
          ),
          JournalQuestion(
            id: "12.4",
            question: "What treatment options are available?",
            paragraphs: [
              "Treatment depends on symptoms, growth size or location, age, anaemia, and pregnancy goals. Options may include monitoring, medication to reduce pain or bleeding, hormonal treatment, uterine-artery procedures, focused procedures, or surgery.",
              "Not every fibroid or case of adenomyosis needs surgery; care should be individualised [25, 26].",
            ],
          ),
        ],
      ),
      JournalSection(
        id: "13",
        title: "PCOS",
        questions: [
          JournalQuestion(
            id: "13.1",
            question: "What is PCOS?",
            paragraphs: [
              "Polycystic ovary syndrome (PCOS) is a hormonal and metabolic condition that may affect ovulation, periods, androgen-related symptoms, fertility, and long-term health. A person does not need ovarian cysts to have PCOS, and an ovarian cyst does not automatically mean PCOS [13].",
            ],
          ),
          JournalQuestion(
            id: "13.2",
            question: "What symptoms can PCOS cause?",
            paragraphs: [
              "Possible features include irregular or absent periods, excess facial or body hair, acne, scalp hair thinning, difficulty becoming pregnant, and insulin resistance. Symptoms differ widely and PCOS occurs across the weight spectrum.",
              "Rapidly developing androgen-related symptoms or voice deepening require prompt assessment for other causes [13].",
            ],
          ),
          JournalQuestion(
            id: "13.3",
            question: "How is PCOS diagnosed?",
            paragraphs: [
              "In adults, diagnosis generally considers ovulatory dysfunction, clinical or biochemical androgen excess, and polycystic ovarian morphology after excluding other causes. Not every person needs an ultrasound.",
              "Diagnosis in adolescents requires additional caution because acne and irregular cycles can be normal during puberty. Ultrasound or anti-Müllerian hormone should not be used alone to diagnose adolescent PCOS [13].",
            ],
          ),
          JournalQuestion(
            id: "13.4",
            question: "How is PCOS managed?",
            paragraphs: [
              "Management can include sustainable lifestyle support, treatment for acne or excess hair, hormonal contraception to regulate bleeding and protect the uterine lining, metformin for selected metabolic or cycle concerns, fertility treatment, and monitoring of glucose, cholesterol, blood pressure, sleep, and mental health.",
              "Treatment should match the person's priorities [13].",
            ],
          ),
          JournalQuestion(
            id: "13.5",
            question: "Does PCOS always cause infertility?",
            paragraphs: [
              "No. PCOS can make ovulation less predictable, but many people with PCOS become pregnant naturally or with treatment. Fertility care may include ovulation assessment, medicine, or assisted reproduction depending on the individual.",
              "Cycle predictions alone should not be used to judge fertility [13].",
            ],
          ),
        ],
      ),
      JournalSection(
        id: "14",
        title: "Amenorrhoea",
        questions: [
          JournalQuestion(
            id: "14.1",
            question: "What is amenorrhoea?",
            paragraphs: [
              "Amenorrhoea means absence of menstrual periods. Primary amenorrhoea generally describes no first period by age 15 or about three years after breast development begins. Secondary amenorrhoea commonly means no periods for three months in someone previously regular or six months in someone previously irregular [16].",
            ],
          ),
          JournalQuestion(
            id: "14.2",
            question: "What can cause periods to stop?",
            paragraphs: [
              "Pregnancy is the first possibility to consider in reproductive-age users. Other causes include breastfeeding, menopause, hormonal contraception, PCOS, thyroid disorders, high prolactin, reduced ovarian function, chronic illness, certain medicines, major stress, insufficient nutrition, significant weight change, and intense exercise [16].",
            ],
          ),
          JournalQuestion(
            id: "14.3",
            question: "Why should amenorrhoea be checked?",
            paragraphs: [
              "The cause may affect fertility, bone health, metabolic health, or general wellbeing. Seek earlier care for pelvic pain, pregnancy symptoms, severe headache, vision changes, nipple discharge, rapid hair growth, hot flushes at a young age, disordered eating, stress fractures, or major weight change [16, 20].",
            ],
          ),
          JournalQuestion(
            id: "14.4",
            question: "How is amenorrhoea evaluated and treated?",
            paragraphs: [
              "Evaluation commonly begins with history and a pregnancy test. Tests may include thyroid-stimulating hormone, prolactin, follicle-stimulating hormone, oestradiol, and androgen levels or an ultrasound.",
              "Treatment targets the cause. Hormones should not be taken simply to trigger bleeding before the reason for missed periods is assessed [16].",
            ],
          ),
        ],
      ),
      JournalSection(
        id: "15",
        title: "Ovarian Cysts and Ovulation Pain",
        questions: [
          JournalQuestion(
            id: "15.1",
            question: "What is an ovarian cyst?",
            paragraphs: [
              "An ovarian cyst is a fluid-filled sac in or on an ovary. Functional cysts can develop as part of the menstrual cycle and commonly disappear without treatment. Other cysts may be related to endometriosis or abnormal cell growth and require assessment [27].",
            ],
          ),
          JournalQuestion(
            id: "15.2",
            question: "Is an ovarian cyst the same as PCOS?",
            paragraphs: [
              "No. A single ovarian cyst is not PCOS. PCOS is a hormonal and metabolic syndrome diagnosed from a combination of cycle, androgen, and ovarian findings after other causes are excluded [13, 27].",
            ],
          ),
          JournalQuestion(
            id: "15.3",
            question: "What is ovulation pain?",
            paragraphs: [
              "Some people experience brief one-sided lower-abdominal discomfort around ovulation. It is sometimes called mittelschmerz. Similar pain can also result from a cyst, endometriosis, infection, or another condition.",
              "Sudden severe pain, pain with vomiting, fever, fainting, pregnancy possibility, or persistent worsening pain requires urgent assessment because torsion, cyst rupture, or ectopic pregnancy may need treatment [27].",
            ],
          ),
        ],
      ),
      JournalSection(
        id: "16",
        title: "Vaginal Health, Infection, and Abnormal Bleeding",
        questions: [
          JournalQuestion(
            id: "16.1",
            question: "What vaginal discharge is normal?",
            paragraphs: [
              "Normal discharge may be clear, white, or pale and can change in amount and texture during the cycle. It may become wetter and more slippery near ovulation. Normal discharge should not usually cause strong odour, significant itching, burning, or pelvic pain [28].",
            ],
          ),
          JournalQuestion(
            id: "16.2",
            question: "What signs may indicate vaginitis or infection?",
            paragraphs: [
              "Possible signs include new strong odour, unusual colour or texture, itching, burning, pain, swelling, discomfort during urination or sex, or pelvic pain. Common causes include bacterial vaginosis, yeast infection, trichomoniasis, other STIs, hormonal dryness, or chemical irritation.",
              "Symptoms overlap, so using leftover treatment without a diagnosis can delay correct care [28].",
            ],
          ),
          JournalQuestion(
            id: "16.3",
            question: "Can an STI change bleeding or discharge?",
            paragraphs: [
              "Yes. Some STIs can cause unusual discharge, bleeding between periods, bleeding after sex, pelvic pain, or pain during urination. Many STIs cause no symptoms, so symptom absence does not rule them out.",
              "Testing is the only reliable way to know whether many STIs are present [29, 30].",
            ],
          ),
          JournalQuestion(
            id: "16.4",
            question: "What is pelvic inflammatory disease?",
            paragraphs: [
              "Pelvic inflammatory disease (PID) is infection and inflammation affecting the uterus, fallopian tubes, or ovaries. Possible symptoms include pelvic pain, unusual discharge, painful sex, heavy or painful periods, and bleeding between periods or after sex.",
              "Early treatment can reduce the risk of long-term pelvic pain, infertility, and ectopic pregnancy [29].",
            ],
          ),
          JournalQuestion(
            id: "16.5",
            question: "When should unusual bleeding be checked?",
            paragraphs: [
              "Arrange assessment for bleeding between periods, after sex, during pregnancy, or after menopause. Also seek care when bleeding is associated with pain, unusual discharge, fever, or a major change from the usual cycle.",
              "A missed period with bleeding and pelvic pain requires urgent evaluation for possible ectopic pregnancy [10].",
            ],
          ),
        ],
      ),
    ],
  ),
  JournalGroup(
    id: "D",
    title: "Fertility, Pregnancy, and Sexual Health",
    sections: [
      JournalSection(
        id: "17",
        title: "Fertility and Pregnancy Awareness",
        questions: [
          JournalQuestion(
            id: "17.1",
            question: "What is the fertile window?",
            paragraphs: [
              "The fertile window includes the days before ovulation and the day of ovulation because sperm can survive for several days while the egg survives for a shorter period. The exact timing varies between cycles.",
              "An app can estimate this window but cannot guarantee the actual ovulation day [1, 21, 22].",
            ],
          ),
          JournalQuestion(
            id: "17.2",
            question: "How can someone identify ovulation?",
            paragraphs: [
              "Possible methods include cervical-mucus observation, basal body temperature, urine luteinising-hormone tests, ultrasound, or laboratory hormone testing. Each method has limitations. Temperature generally rises after ovulation, while urine testing predicts a hormonal surge rather than guaranteeing egg release.",
              "Calendar dates alone are particularly limited with irregular cycles [2, 13].",
            ],
          ),
          JournalQuestion(
            id: "17.3",
            question: "When should a pregnancy test be taken?",
            paragraphs: [
              "Follow the test manufacturer's timing instructions. Testing is appropriate when a period is late after pregnancy-risk sex, contraception failed, or pregnancy symptoms occur. A negative result taken too early may need repeating.",
              "Seek medical advice for repeated negative tests with persistent missed periods or for any positive test accompanied by significant bleeding or pain. Home urine tests are most reliable when used at the correct time and exactly as instructed [40].",
            ],
          ),
          JournalQuestion(
            id: "17.4",
            question: "Is bleeding during early pregnancy normal?",
            paragraphs: [
              "Light bleeding can occur in early pregnancy, but an app cannot determine whether it is harmless. Pregnancy-related bleeding may also be associated with miscarriage, ectopic pregnancy, infection, or another cause.",
              "Urgent assessment is required for heavy bleeding, severe or one-sided pelvic pain, shoulder pain, dizziness, fainting, or feeling very unwell [10].",
            ],
          ),
          JournalQuestion(
            id: "17.5",
            question: "When should fertility support be considered?",
            paragraphs: [
              "Professional advice is appropriate when pregnancy is desired but cycles are absent or very irregular, when there are symptoms of PCOS or endometriosis, or after a period of regular unprotected intercourse without pregnancy. The recommended timing varies with age and medical history.",
              "Seeking advice does not mean infertility is confirmed. Fertility evaluation is designed to identify relevant factors in an organised and cost-effective way [41].",
            ],
          ),
        ],
      ),
      JournalSection(
        id: "18",
        title: "Contraception and Sexual Health",
        questions: [
          JournalQuestion(
            id: "18.1",
            question: "What are the main contraceptive choices?",
            paragraphs: [
              "Options include implants and IUDs, pills, injections, patches, vaginal rings, external and internal condoms, diaphragms, permanent methods, structured fertility-awareness methods, and emergency contraception.",
              "Choice should be voluntary and based on effectiveness, safety, side effects, privacy, control, cost, reversibility, and pregnancy plans [12].",
            ],
          ),
          JournalQuestion(
            id: "18.2",
            question: "Which methods are most effective?",
            paragraphs: [
              "Implants and IUDs have typical-use failure rates below 1% in CDC data. Pills, patches, rings, injections, and condoms depend more on correct and consistent use.",
              "Medical history, migraine type, smoking, blood-clot risk, medication interactions, and bleeding preferences may affect suitability [12].",
            ],
          ),
          JournalQuestion(
            id: "18.3",
            question: "How can contraception affect periods?",
            paragraphs: [
              "Hormonal methods may make bleeding lighter, less painful, irregular, or absent. A copper IUD may make periods heavier or more painful, especially at first. These changes do not automatically mean the method has failed.",
              "Seek advice for severe pain, very heavy bleeding, pregnancy possibility, or side effects that feel unsafe [12].",
            ],
          ),
          JournalQuestion(
            id: "18.4",
            question: "Do contraceptives protect against STIs?",
            paragraphs: [
              "Most contraceptive methods do not protect against STIs. Correct and consistent condom use reduces the risk of many STIs and pregnancy but does not eliminate all risk.",
              "Using condoms with another effective contraceptive method provides dual protection. Testing and vaccination where appropriate remain important [30, 31, 35].",
            ],
          ),
          JournalQuestion(
            id: "18.5",
            question: "What is emergency contraception?",
            paragraphs: [
              "Emergency contraception can reduce pregnancy risk after unprotected sex, missed contraception, or condom failure. Options include emergency contraceptive pills and a copper IUD. Timing, medicines, body factors, and local availability affect the suitable option.",
              "Contact a pharmacist or clinic as soon as possible. Emergency contraception does not provide ongoing protection for later sex [12].",
            ],
          ),
          JournalQuestion(
            id: "18.6",
            question: "Can LUNA Health be used as birth control?",
            paragraphs: [
              "No. Standard period tracking is not contraception. Research shows that many apps inaccurately estimate ovulation and fertile days. LUNA Health may support cycle awareness, but users wishing to avoid pregnancy should use a recognised contraceptive method [21, 22].",
            ],
          ),
        ],
      ),
    ],
  ),
  JournalGroup(
    id: "E",
    title: "Periods Across Life Stages",
    sections: [
      JournalSection(
        id: "19",
        title: "Postpartum and Breastfeeding Periods",
        questions: [
          JournalQuestion(
            id: "19.1",
            question: "What is postpartum bleeding?",
            paragraphs: [
              "Bleeding after birth, called lochia, is not the first menstrual period. It contains blood and tissue from the uterus and normally changes in amount and colour as recovery progresses.",
              "Sudden very heavy bleeding, large clots, faintness, fever, worsening abdominal pain, or foul-smelling discharge requires urgent postpartum medical care [32].",
            ],
          ),
          JournalQuestion(
            id: "19.2",
            question: "When will periods return after pregnancy?",
            paragraphs: [
              "Timing varies. For people who bottle-feed or combine feeding methods, a period may return as early as five to six weeks after birth. Exclusive breastfeeding can delay its return, sometimes until feeding frequency reduces.",
              "The first cycles may differ from the pre-pregnancy pattern [32].",
            ],
          ),
          JournalQuestion(
            id: "19.3",
            question: "Can pregnancy happen before the first postpartum period?",
            paragraphs: [
              "Yes. Ovulation happens before the following period, so fertility can return before the first visible postpartum bleed. Do not wait for menstruation to restart before considering contraception [33].",
            ],
          ),
          JournalQuestion(
            id: "19.4",
            question: "Is breastfeeding reliable contraception?",
            paragraphs: [
              "Breastfeeding can reduce pregnancy risk only under the specific lactational amenorrhoea method criteria: the baby is under six months, feeding is fully or nearly fully breastfeeding at appropriate intervals, and periods have not returned. If any condition changes, another method is needed.",
              "Expressing patterns and reduced night feeding can affect reliability, so professional advice is recommended [33].",
            ],
          ),
        ],
      ),
      JournalSection(
        id: "20",
        title: "Perimenopause and Menopause",
        questions: [
          JournalQuestion(
            id: "20.1",
            question: "What are perimenopause, menopause, and postmenopause?",
            paragraphs: [
              "Perimenopause is the transition before menopause when cycles and symptoms may change. Menopause is confirmed after 12 consecutive months without a period when there is no other cause. Postmenopause is the stage afterward.",
              "Natural menopause most often occurs between ages 45 and 55 [14].",
            ],
          ),
          JournalQuestion(
            id: "20.2",
            question: "What symptoms can occur?",
            paragraphs: [
              "Possible symptoms include irregular periods, hot flushes, night sweats, sleep disruption, mood changes, concentration difficulty, joint discomfort, vaginal dryness, urinary symptoms, and changes in sexual desire.",
              "Other conditions can cause similar symptoms, so new concerns should not automatically be attributed to menopause [14].",
            ],
          ),
          JournalQuestion(
            id: "20.3",
            question: "Can pregnancy still happen during perimenopause?",
            paragraphs: [
              "Yes. Ovulation becomes unpredictable but can still occur until menopause is established. Someone who does not want pregnancy should continue suitable contraception until a clinician advises it can be stopped.",
              "Menopausal hormone therapy is not contraception [12, 14].",
            ],
          ),
          JournalQuestion(
            id: "20.4",
            question: "How can menopause symptoms be treated?",
            paragraphs: [
              "Options include sleep and temperature strategies, activity, psychological support, vaginal moisturisers or lubricants, hormone therapy, and evidence-based non-hormonal treatments. Hormone therapy is the most effective treatment for hot flushes and night sweats and can prevent bone loss, but its risks and benefits depend on individual factors.",
              "Treatment must be personalised and periodically reviewed [15].",
            ],
          ),
          JournalQuestion(
            id: "20.5",
            question: "Is bleeding after menopause normal?",
            paragraphs: [
              "No episode should be ignored. Even a small amount of spotting or pink or brown discharge after confirmed menopause should be assessed. Many causes are benign, but some require early treatment.",
              "LUNA Health should display a clear medical-review prompt for any bleeding recorded after menopause [10, 14].",
            ],
          ),
        ],
      ),
    ],
  ),
  JournalGroup(
    id: "F",
    title: "Getting Professional Help",
    sections: [
      JournalSection(
        id: "21",
        title: "Medical Assessment and Safety",
        questions: [
          JournalQuestion(
            id: "21.1",
            question: "When should I see a healthcare professional about periods?",
            paragraphs: [
              "Arrange care when bleeding, pain, missed periods, discharge, or emotional symptoms are new, persistent, worsening, or interfere with school, work, sleep, relationships, or ordinary activities. Care is also appropriate whenever the person is worried.",
              "Symptoms do not need to become unbearable before they deserve assessment [20].",
            ],
          ),
          JournalQuestion(
            id: "21.2",
            question: "What should I record before an appointment?",
            paragraphs: [
              "Record period dates, flow, product-change frequency, clots, spotting, pain location and severity, discharge, pregnancy possibility, medication, contraception, associated symptoms, and the effect on daily life. Bring relevant pregnancy-test results and family history.",
              "Clear records can help the clinician select appropriate tests without replacing professional assessment [1].",
            ],
          ),
          JournalQuestion(
            id: "21.3",
            question: "What tests might be performed?",
            paragraphs: [
              "Depending on the concern, evaluation may include a pregnancy test, blood count, ferritin, thyroid testing, prolactin, reproductive hormones, STI testing, pelvic examination, ultrasound, or other imaging. Not every patient needs every test.",
              "The clinician should explain the purpose, benefits, limitations, and alternatives and obtain consent before an intimate examination [9, 10, 16].",
            ],
          ),
          JournalQuestion(
            id: "21.4",
            question: "What should LUNA Health do when it detects warning signs?",
            paragraphs: [
              "The app should:",
              "- Display a clear action message rather than a diagnosis.",
              "- Distinguish routine, prompt, and urgent care.",
              "- Explain which logged symptoms triggered the warning.",
              "- Advise pregnancy testing when appropriate.",
              "- Allow users to export a concise symptom record.",
              "- Never reassure users that serious disease has been excluded.",
              "Medical content and decision rules must be clinically reviewed before release and reassessed at least annually. This is especially important for fertile-window warnings because published evaluations have identified inaccurate information in many period-tracking apps [21, 22].",
            ],
          ),
        ],
      ),
    ],
  ),
];
