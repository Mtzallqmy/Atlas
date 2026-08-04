import type { Organ, OrganId } from "./anatomy-data";

export type Locale = "en" | "ar";

export const ui = {
  en: {
    brandTagline: "Learn anatomy like an artist",
    explore: "Explore", systems: "Systems", lessons: "Lessons", library: "Library", notes: "Notes",
    search: "Search organs and topics…", profile: "Open learner profile", openLibrary: "Open organ library",
    organLibrary: "Organ library", closeLibrary: "Close library", saved: "Saved organs", viewAll: "View all organs",
    curiosity: "Learning is an act of curiosity.", keepExploring: "Keep exploring!", the: "The",
    keyFacts: "Key facts", size: "Size", weight: "Weight", daily: "Daily", location: "Location",
    bloodSupply: "Blood supply", function: "Function", medicalImportance: "Medical importance", didYouKnow: "Did you know",
    viewLesson: "View lesson", animate: "Animate", quiz: "Quiz", compare: "Compare", comparing: "Comparing",
    reference: "Reference", primaryRole: "Primary role", scale: "Scale", microscopicView: "Microscopic view",
    exploreTissue: "Explore tissue", compareOrgans: "Compare organs", openComparison: "Open comparison",
    functionAnimation: "Function animation", playAnimation: "Play animation", clinicalNotes: "Clinical notes",
    commonConditions: "Common conditions", seeAll: "See all", whereItWorks: "Where it works", seeSystem: "See the system",
    guidedDiscovery: "Guided discovery", continueExploring: "Continue exploring", system: "System",
    language: "العربية", footer: "Programming and development: Moataz Alalqami",
    quizQuestion: "Which statement best describes this organ?",
    quizA: "It plays a specialized role in maintaining the body", quizB: "It works completely independently", quizC: "It is active only during sleep",
    lessonCopy: "Follow the highlighted structures, rotate the specimen, and connect form with function. This short study moment is designed to build a durable mental model.",
    systemCopy: "Trace how this organ connects to the rest of the body.",
    close: "Close",
  },
  ar: {
    brandTagline: "تعلّم التشريح بمنظور علمي وفني",
    explore: "استكشاف", systems: "الأجهزة", lessons: "الدروس", library: "المكتبة", notes: "الملاحظات",
    search: "ابحث عن عضو أو موضوع…", profile: "فتح ملف المتعلم", openLibrary: "فتح مكتبة الأعضاء",
    organLibrary: "مكتبة الأعضاء", closeLibrary: "إغلاق المكتبة", saved: "الأعضاء المحفوظة", viewAll: "عرض جميع الأعضاء",
    curiosity: "التعلّم رحلة تبدأ بالفضول.", keepExploring: "واصل الاستكشاف!", the: "عضو",
    keyFacts: "حقائق أساسية", size: "الحجم", weight: "الوزن", daily: "يوميًا", location: "الموقع",
    bloodSupply: "التروية الدموية", function: "الوظيفة", medicalImportance: "الأهمية الطبية", didYouKnow: "هل تعلم؟",
    viewLesson: "عرض الدرس", animate: "تحريك", quiz: "اختبار", compare: "مقارنة", comparing: "تتم مقارنة",
    reference: "المرجع", primaryRole: "الدور الأساسي", scale: "الحجم التقريبي", microscopicView: "منظر مجهري",
    exploreTissue: "استكشاف النسيج", compareOrgans: "مقارنة الأعضاء", openComparison: "فتح المقارنة",
    functionAnimation: "محاكاة الوظيفة", playAnimation: "تشغيل المحاكاة", clinicalNotes: "ملاحظات سريرية",
    commonConditions: "حالات شائعة", seeAll: "عرض الكل", whereItWorks: "موضعه في الجسم", seeSystem: "عرض الجهاز",
    guidedDiscovery: "استكشاف موجّه", continueExploring: "متابعة الاستكشاف", system: "الجهاز",
    language: "English", footer: "برمجة وتطوير: معتز العلقمي",
    quizQuestion: "أي عبارة تصف هذا العضو بصورة أدق؟",
    quizA: "يؤدي دورًا متخصصًا في الحفاظ على وظائف الجسم", quizB: "يعمل بصورة مستقلة تمامًا", quizC: "ينشط أثناء النوم فقط",
    lessonCopy: "تتبّع التراكيب المحددة، وأدر النموذج، واربط بين الشكل والوظيفة لبناء فهم تشريحي واضح وقابل للتذكر.",
    systemCopy: "تتبّع ارتباط هذا العضو ببقية أجزاء الجسم.",
    close: "إغلاق",
  },
} as const;

const arOrgans: Record<OrganId, Partial<Organ>> = {
  heart: { name: "القلب", system: "الجهاز القلبي الوعائي", poetic: "المضخة التي لا تتوقف", description: "عضو عضلي يضخ الدم إلى أنحاء الجسم لتوصيل الأكسجين والعناصر الغذائية إلى الخلايا.", size: "بحجم قبضة اليد تقريبًا", weight: "250–350 غ", location: "خلف عظم القص مع ميل بسيط إلى اليسار", function: "ضخ الدم المؤكسج إلى الجسم", dailyFact: "ينبض نحو 100 ألف مرة", medical: "ينظم النظام الكهربائي للقلب توقيت كل نبضة وتناسقها.", bloodSupply: "الشريانان التاجيان الأيمن والأيسر", funFact: "ينبض القلب مليارات المرات خلال العمر ويبدأ عمله قبل الولادة.", tissue: "النسيج العضلي القلبي", comparison: "القلب مقارنة بالدماغ", conditions: ["مرض الشرايين التاجية", "اضطراب النظم", "أمراض الصمامات", "قصور القلب", "اعتلال عضلة القلب", "التهاب عضلة القلب", "الرجفان الأذيني", "عيوب القلب الخِلقية"] },
  brain: { name: "الدماغ", system: "الجهاز العصبي", poetic: "عالم داخل الإنسان", description: "مركز التحكم في الجسم؛ يدمج الإحساس والذاكرة والانفعال والحركة الدقيقة.", size: "بحجم قبضتين تقريبًا", weight: "1.3–1.4 كغ", location: "داخل الجمجمة", function: "معالجة الإشارات وتنسيقها", dailyFact: "يستهلك قرابة 20٪ من طاقة الجسم", medical: "تتواصل مليارات الخلايا العصبية بإشارات كهربائية وكيميائية.", bloodSupply: "الشرايين السباتية الداخلية والفقرية", funFact: "نسيج الدماغ نفسه لا يحتوي مستقبلات للألم.", tissue: "القشرة المخية", comparison: "الدماغ مقارنة بالعين", conditions: ["الصداع النصفي", "السكتة الدماغية", "الأمراض التنكسية العصبية", "الصرع", "إصابات الدماغ", "التهاب السحايا", "التصلب المتعدد", "تمدد الأوعية الدماغية"] },
  lungs: { name: "الرئتان", system: "الجهاز التنفسي", poetic: "نَفَس الحياة", description: "عضوان يستقبلان الهواء ويتبادلان الأكسجين وثاني أكسيد الكربون عبر سطح دقيق واسع.", size: "ارتفاع كل رئة نحو 25 سم", weight: "نحو 1 كغ للرئتين", location: "داخل القفص الصدري على جانبي القلب", function: "تبادل الأكسجين وثاني أكسيد الكربون", dailyFact: "تحركان قرابة 11 ألف لتر من الهواء", medical: "توفّر الحويصلات الهوائية مساحة كبيرة لتبادل الغازات.", bloodSupply: "الشرايين الرئوية والقصبية", funFact: "للرئة اليمنى ثلاثة فصوص، بينما لليسرى فصان لإتاحة مساحة للقلب.", tissue: "النسيج الحويصلي", comparison: "الرئتان مقارنة بالقلب", conditions: ["الربو", "الانسداد الرئوي المزمن", "الالتهاب الرئوي", "الانصمام الرئوي", "التليف الرئوي", "التهاب القصبات", "التليف الكيسي", "سرطان الرئة"] },
  liver: { name: "الكبد", system: "الجهاز الهضمي", poetic: "المختبر الهادئ", description: "عضو استقلابي يرشح الدم ويعالج المغذيات ويسهم في إزالة السموم وإنتاج الصفراء.", size: "بحجم كرة قدم تقريبًا", weight: "1.4–1.6 كغ", location: "الجزء العلوي الأيمن من البطن", function: "الاستقلاب وإزالة السموم وإنتاج الصفراء", dailyFact: "ينفذ أكثر من 500 وظيفة", medical: "يمتلك قدرة ملحوظة على تجدد جزء كبير من نسيجه.", bloodSupply: "الشريان الكبدي والوريد البابي", funFact: "يمكن للكبد استعادة حجمه بعد فقد جزء معتبر منه.", tissue: "الفصيصات الكبدية", comparison: "الكبد مقارنة بالأمعاء", conditions: ["الكبد الدهني", "التهاب الكبد", "تشمع الكبد", "حصوات المرارة", "داء ترسب الأصبغة الدموية", "سرطان الكبد", "التهاب الكبد المناعي", "ارتفاع ضغط الوريد البابي"] },
  kidneys: { name: "الكليتان", system: "الجهاز البولي", poetic: "مرشحات الجسم الدقيقة", description: "عضوان يرشحان الدم ويحافظان على توازن السوائل والأملاح وضغط الدم والتخلص من الفضلات.", size: "كل كلية بحجم فأرة الحاسوب تقريبًا", weight: "120–170 غ لكل كلية", location: "على جانبي العمود الفقري أسفل الأضلاع", function: "ترشيح الدم وتكوين البول", dailyFact: "ترشحان نحو 180 لترًا من السوائل", medical: "تضبط النفرونات تركيب الدم بدقة وتعيد امتصاص المواد المهمة.", bloodSupply: "الشرايين الكلوية", funFact: "لا يخرج كبول إلا جزء صغير جدًا مما ترشحه الكليتان.", tissue: "قشرة الكلية", comparison: "الكليتان مقارنة بالكبد", conditions: ["حصوات الكلى", "مرض الكلى المزمن", "عدوى المسالك البولية", "التهاب كبيبات الكلى", "تكيس الكلى", "ارتفاع الضغط الكلوي", "إصابة الكلى الحادة", "المتلازمة النفروزية"] },
  eyeball: { name: "العين", system: "الجهاز الحسي", poetic: "نافذة من الضوء", description: "عضو حسي دقيق يحول الضوء المركّز إلى إشارات عصبية يفسرها الدماغ كرؤية.", size: "قطرها نحو 24 مم", weight: "نحو 7.5 غ", location: "داخل الحجاج العظمي", function: "استقبال الضوء وتركيزه", dailyFact: "تنفذ آلاف الحركات الدقيقة", medical: "تُعد الشبكية امتدادًا للجهاز العصبي المركزي.", bloodSupply: "الشريان العيني", funFact: "القرنية خالية من الأوعية الدموية وتحصل على الأكسجين مباشرة من الهواء.", tissue: "طبقات الشبكية", comparison: "العين مقارنة بالدماغ", conditions: ["قصر النظر", "الساد", "الزرق", "التنكس البقعي", "انفصال الشبكية", "جفاف العين", "الاستجماتيزم", "التهاب الملتحمة"] },
  intestine: { name: "الأمعاء", system: "الجهاز الهضمي", poetic: "الحديقة الداخلية", description: "قناة هضمية ملتفة تُمتص فيها المغذيات وتعيش فيها كائنات دقيقة تدعم صحة الجسم.", size: "نحو 6–7 أمتار عند امتدادها", weight: "يتغير حسب المحتوى", location: "منتصف وأسفل البطن", function: "الهضم وامتصاص المغذيات", dailyFact: "تستضيف تريليونات الكائنات الدقيقة", medical: "تزيد الطيات والزغابات والزغيبات مساحة الامتصاص بدرجة كبيرة.", bloodSupply: "الشريانان المساريقيان العلوي والسفلي", funFact: "تتجدد بطانة الأمعاء خلال أيام قليلة.", tissue: "الزغابات المعوية", comparison: "الأمعاء مقارنة بالكبد", conditions: ["متلازمة القولون العصبي", "أمراض الأمعاء الالتهابية", "الداء البطني", "التهاب الرتوج", "انسداد الأمعاء", "سلائل القولون", "داء كرون", "عدم تحمل اللاكتوز"] },
  pancreas: { name: "البنكرياس", system: "الجهاز الهضمي والغدد الصماء", poetic: "المنظم الهادئ", description: "غدة تؤدي وظيفتين: إفراز إنزيمات هاضمة وإنتاج هرمونات تضبط مستوى سكر الدم.", size: "طوله نحو 15 سم", weight: "70–100 غ", location: "خلف المعدة", function: "الهضم وتنظيم سكر الدم", dailyFact: "يفرز إنزيمات وهرمونات متخصصة", medical: "تنتج جزر لانغرهانس الإنسولين والغلوكاغون للمحافظة على توازن الغلوكوز.", bloodSupply: "فروع من الشريان الطحالي والبنكرياسي الاثناعشري", funFact: "يجمع البنكرياس بين وظيفة هضمية ووظيفة هرمونية في عضو واحد.", tissue: "جزر لانغرهانس", comparison: "البنكرياس مقارنة بالكبد", conditions: ["التهاب البنكرياس", "السكري", "سرطان البنكرياس", "قصور البنكرياس", "الأكياس البنكرياسية", "التهاب البنكرياس المناعي", "أورام الغدد الصماء", "التليف الكيسي"] },
  skin: { name: "الجلد", system: "الجهاز اللحافي", poetic: "الحد الفاصل الحي", description: "أكبر أعضاء الجسم؛ يشكل حاجزًا واقيًا ويسهم في الإحساس وتنظيم الحرارة والمناعة.", size: "يغطي مساحة تقارب 1.5–2 م²", weight: "نحو 3–5 كغ", location: "يغطي كامل سطح الجسم", function: "الحماية والإحساس وتنظيم الحرارة", dailyFact: "يجدد ملايين الخلايا باستمرار", medical: "تعمل طبقاته كحاجز مناعي وميكانيكي معقد.", bloodSupply: "شبكات وعائية جلدية", funFact: "يتجدد معظم سطح الجلد خلال نحو شهر.", tissue: "طبقات البشرة والأدمة", comparison: "الجلد مقارنة بالأمعاء", conditions: ["الأكزيما", "الصدفية", "حب الشباب", "التهاب الجلد", "سرطان الجلد", "الشرى", "العدوى الجلدية", "الحروق"] },
};

export function localizeOrgan(organ: Organ, locale: Locale): Organ {
  if (locale === "en") return organ;
  return { ...organ, ...arOrgans[organ.id] };
}
