# Anatomy Atlas — أطلس التشريح التفاعلي

منصة تعليم طبي تفاعلية **Offline‑First** لدراسة التشريح البشري، وظائف الأعضاء، الأنسجة، الباثولوجي، والأمراض. يتكون المشروع من تطبيق Flutter أصلي للمستخدم، لوحة إدارة ويب احترافية، وبنية Backend آمنة على Supabase.

> **المحتوى تعليمي فقط، ولا يمثل تشخيصًا أو خطة علاج شخصية.**

**تطوير وبرمجة: معتز العلقمي**

---

## ما الذي يقدمه المشروع؟

- تطبيق Flutter أصلي يدعم Android أولًا، مع بنية جاهزة لـ iOS والويب واللوحيات.
- مستكشف ثلاثي الأبعاد يعتمد GLB/GLTF مع بديل ثنائي الأبعاد عند فشل النموذج.
- محتوى عربي وإنجليزي مضمّن يعمل دون تسجيل أو اتصال بالإنترنت.
- صفحات أعضاء موثقة تشمل الوظيفة، الموقع، التروية، التعصيب، الأهمية السريرية والمراجع.
- بحث محلي عربي/إنجليزي مع إزالة التشكيل وتطبيع محافظ للحروف العربية.
- حزم محتوى قابلة للتنزيل مع الاستئناف، SHA‑256، النسخ الاحتياطي والرجوع عند فساد التحديث.
- ملاحظات ومفضلة وتقدم دراسي محلي، مع مخطط مزامنة آمن للمستخدم المسجل.
- لوحة إدارة متجاوبة لإدارة الأجهزة، الأعضاء، الأجزاء، الأمراض، الباثولوجي، الدروس، الاختبارات، الترجمات والمراجع.
- إدارة الصور، النماذج ثلاثية الأبعاد والملفات مع checksum وبيانات الترخيص ونسبة المصدر.
- سير عمل طبي: `draft → under_review → medically_reviewed → published → archived`.
- مراجعات طبية، إصدارات قابلة للاستعادة، سجل عمليات، وفحوص سلامة وإصلاحات آمنة للبيانات.
- AI Tutor اختياري ومعزول خلف Edge Function، ويعمل التطبيق افتراضيًا في وضع `disabled`.

## التقنيات

### تطبيق المستخدم

- Flutter وDart مع Null Safety وMaterial 3.
- Riverpod لإدارة الحالة وحقن الاعتماديات.
- GoRouter للتنقل والروابط العميقة.
- Freezed و`json_serializable` للنماذج.
- Drift فوق SQLite للتخزين المحلي.
- Dio للتنزيلات والاتصال المنظم.
- `flutter_secure_storage` للأسرار المحلية المسموح بها.
- `interactive_3d` لعرض GLB أصليًا عبر Filament على Android وSceneKit على iOS.
- ARB و`flutter_localizations` مع RTL كامل.

### لوحة الإدارة والخادم

- Next.js وReact وTypeScript.
- Supabase Auth وPostgreSQL وStorage وEdge Functions.
- Row Level Security على البيانات الخاصة والإدارية.
- PostgreSQL Full‑Text/Trigram Search وتطبيع البحث العربي.
- Migrations وSeed وpgTAP داخل المستودع.
- OpenAI Responses API من الخادم فقط عند تفعيل AI.

## معمارية المستودع

```text
.
├── app/                         # العرض الويب الحالي ولوحة الإدارة
│   ├── admin/                   # لوحة التحكم المتجاوبة
│   ├── components/              # معاينة Anatomy Atelier الحالية
│   └── lib/supabase-browser.ts  # عميل Auth/REST محدود بالمفتاح العام وRLS
├── mobile/                      # تطبيق Flutter الأصلي
│   ├── assets/                  # الحزمة الأساسية والصور وGLB
│   ├── lib/app/                 # bootstrap، router، theme
│   ├── lib/core/                # DB، downloads، AI، logging، utilities
│   ├── lib/features/            # feature-first presentation/data/domain
│   ├── test/                    # Unit وWidget tests
│   └── integration_test/        # اختبارات التدفق الكامل
├── supabase/
│   ├── migrations/              # مخطط PostgreSQL وRLS والعمليات المحمية
│   ├── functions/               # owner-settings، owner-transfer، ai-tutor
│   ├── tests/                   # pgTAP واختبارات Edge Functions
│   ├── config.toml
│   └── seed.sql
├── scripts/
│   ├── bootstrap-owner.mjs      # إنشاء المالك الأولي من البيئة فقط
│   └── bootstrap-mobile.sh      # إنشاء platform runners وتوليد الكود
└── .github/workflows/ci.yml
```

## المتطلبات

- Node.js 22 أو أحدث.
- Flutter 3.44 أو أحدث وAndroid SDK.
- Docker لتشغيل Supabase محليًا.
- Supabase CLI.
- Deno 2 لاختبارات Edge Functions المحلية.

## الإعداد السريع

### 1. إعداد المتغيرات

```bash
cp .env.example .env.local
```

ضع القيم الحقيقية في مدير أسرار أو ملف محلي غير متتبع. لا تضع `SUPABASE_SERVICE_ROLE_KEY` أو كلمة مرور المالك في Flutter أو كود المتصفح أو المستودع.

المتغيرات العامة للوحة:

```env
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

المتغيرات الخادمية اللازمة لإنشاء المالك:

```env
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=...
INITIAL_OWNER_USERNAME=owner
INITIAL_OWNER_EMAIL=owner@example.com
INITIAL_OWNER_PASSWORD=...
```

يجب أن تكون كلمة المرور المؤقتة فريدة وقوية، ولا تُحفظ في أي ملف ملتزم به في Git.

### 2. تشغيل Supabase محليًا

```bash
supabase start
supabase db reset
supabase test db
```

ينفذ `db reset` جميع migrations ثم `supabase/seed.sql`. لا ينشئ seed أي مستخدم أو كلمة مرور.

### 3. إنشاء المالك الأولي

حمّل المتغيرات في جلسة الطرفية أو مدير الأسرار، ثم:

```bash
npm run owner:bootstrap
```

السكربت:

1. يتحقق من عدم وجود مالك حالي.
2. ينشئ Supabase Auth user عبر Admin API الخادمية فقط.
3. يستدعي RPC لا تقبل إلا `service_role`.
4. يربط المستخدم بدور `owner` في `profiles`.
5. يضع `must_change_credentials=true`.
6. ينفذ rollback للمستخدم الذي أنشأه إذا فشلت عملية ربط الدور.

عند أول تسجيل دخول، لا يستطيع المالك متابعة الإدارة قبل تغيير **اسم المستخدم والبريد وكلمة المرور**. لا تعرض لوحة التحكم كلمة المرور ولا تخزنها. تحديث الحساب يعيد التحقق من كلمة المرور الحالية، يحدّث Auth ثم `profiles`، وينفذ rollback تعويضيًا عند فشل المزامنة.

### 4. تشغيل لوحة الإدارة

```bash
npm ci
npm run admin:dev
```

ثم افتح:

```text
http://localhost:3000/admin/login
```

يمكن تشغيل واجهة Vinext الحالية عبر:

```bash
npm run dev
```

## إعداد تطبيق Flutter

لأن ملفات platform runner تعتمد على نسخة Flutter المثبتة، أنشئها مرة واحدة ثم ولّد ملفات Freezed/Drift/localization:

```bash
npm run mobile:bootstrap
```

أو يدويًا:

```bash
cd mobile
flutter create --platforms=android,ios,web --project-name anatomy_atlas --org com.anatomyatlas .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```

تشغيل Android دون AI:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY \
  --dart-define=AI_PROVIDER_MODE=disabled
```

لا يحتاج المحتوى الأساسي أو البحث المحلي أو النموذج المضمّن إلى Supabase. إذا لم تمرر القيم، يعمل التطبيق بمحتواه المحلي فقط.

## إعداد Supabase للإنتاج

### تطبيق migrations

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

### نشر Edge Functions

```bash
supabase functions deploy owner-settings
supabase functions deploy owner-transfer
supabase functions deploy ai-tutor
```

### ضبط الأسرار

توفّر Supabase تلقائيًا داخل Edge Functions المتغيرات `SUPABASE_URL` و`SUPABASE_ANON_KEY` و`SUPABASE_SERVICE_ROLE_KEY`؛ لا تُرسل قيمة service role إلى العميل.

```bash
supabase secrets set \
  AI_PROVIDER_MODE=disabled \
  AI_DAILY_USER_QUOTA=20
```

عند استخدام مزود تديره المنصة:

```bash
supabase secrets set \
  AI_PROVIDER_MODE=platformManaged \
  OPENAI_API_KEY=... \
  OPENAI_BASE_URL=https://api.openai.com/v1 \
  OPENAI_MODEL=YOUR_SERVER_SELECTED_MODEL
```

لا يثبت التطبيق اسم نموذج داخل واجهة Flutter. يمكن تغيير `OPENAI_BASE_URL` و`OPENAI_MODEL` من أسرار الخادم لمزود OpenAI‑compatible.

## أدوار وصلاحيات لوحة الإدارة

| الدور | النطاق |
|---|---|
| `owner` | مالك وحيد محمي؛ الإعدادات، المستخدمون، السجل والعمليات الحساسة |
| `admin` | إدارة المحتوى والملفات والتشغيل اليومي |
| `editor` | إنشاء وتحرير المحتوى التعليمي |
| `medical_reviewer` | إصدار قرارات المراجعة الطبية |
| `translator` | إدارة الترجمات والمصطلحات |
| `user` | متعلم عادي |

يوجد unique partial index يمنع وجود مالكين نشطين، وtrigger يمنع خفض أو حذف المالك. تغيير أدوار المستخدمين يمر عبر `admin_update_user_access` ولا يسمح بتعيين `owner`. نقل الملكية عملية منفصلة عبر `owner-transfer`، تتطلب إعادة تحقق حديثة ولا تقبل إلا هدفًا موجودًا ومؤهلًا.

## قدرات لوحة التحكم

- CRUD وأرشفة آمنة للأجهزة، الأعضاء، الأجزاء، الباثولوجي، الأمراض، الدروس، الاختبارات، الترجمات والمراجع.
- إدارة إعدادات التطبيق والقوائم والصفحات من قسم مستقل.
- رفع ملفات إلى bucket خاص، مع SHA‑256 وmetadata وترخيص ونسبة المصدر.
- قرارات مراجعة طبية مرتبطة بنوع الكيان ومعرفه وإصداره.
- استعادة إصدار سابق مع حفظ الحالة الحالية تلقائيًا كإصدار جديد.
- Dashboard لعدد السجلات، المسودات، مشاكل البيانات والملفات.
- Integrity Report للسجلات دون مراجع، الأصول دون checksum، الروابط الناقصة وغيرها.
- Safe Patch يسمح فقط بمجموعة حقول إصلاح محددة، ولا يحذف العلاقات أو البيانات.
- Error Boundary على مستوى لوحة الإدارة وصفحات خطأ قابلة لإعادة المحاولة.
- إرسال أخطاء الواجهة إلى `moderation_queue` دون مفاتيح أو كلمات مرور.
- سجل `audit_logs` للعمليات الحساسة وتغييرات الإعدادات والوصول والمراجعة.

## إضافة محتوى طبي

1. أنشئ السجل من لوحة الإدارة بحالة `draft`.
2. أضف النص الأساسي وحقول العضو أو المرض.
3. أضف الترجمة في جدول `translations` مع حالة مناسبة.
4. اربط مرجعًا عبر `content_references` وحدد `locator` مثل الفصل أو الصفحة أو القسم.
5. ارفع الصور/GLB وأدخل الترخيص وattribution وchecksum.
6. اطلب مراجعة طبية.
7. يصدر `medical_reviewer` أو `owner` قرار `approved`.
8. غيّر الحالة إلى `published`.

قاعدة البيانات تمنع نشر المحتوى الطبي الحساس دون مرجع ومراجعة معتمدة. لا تعتبر استجابة AI مرجعًا، ولا تستطيع Edge Function تعديل المحتوى المنشور مباشرة.

## بنية المراجع والترجمات

يدعم المرجع: العنوان، المؤلفون/الجهة، الطبعة، السنة، DOI، PMID، الرابط، تاريخ الوصول، مستوى الدليل، نص الاستشهاد وحالة التفعيل.

تستخدم ترجمة المحتوى جدولًا منفصلًا بدل أعمدة لغة متعددة. الحالات المدعومة:

```text
missing
machine_generated
human_reviewed
medical_reviewed
published
outdated
```

ترجمة الواجهة نفسها موجودة في:

```text
mobile/lib/l10n/app_ar.arb
mobile/lib/l10n/app_en.arb
```

## Offline‑First وحزم المحتوى

تحتوي الحزمة الأساسية داخل APK على القلب، النصوص العربية والإنجليزية، صورة fallback، GLB، وبيانات البحث الأولية.

مثال manifest:

```json
{
  "packageId": "cardiovascular-ar-v1",
  "version": 1,
  "locale": "ar",
  "size": 24500000,
  "checksum": "SHA256_HEX",
  "minimumAppVersion": "1.0.0",
  "downloadUrl": "https://cdn.example.com/cardiovascular-ar-v1.zip",
  "assets": []
}
```

مدير التنزيل يدعم Range resume، الإيقاف، التحقق من SHA‑256، Wi‑Fi only، metadata في Drift، النسخة الاحتياطية `.bak` والرجوع عند فشل التحديث.

## AI Tutor

طبقة Flutter هي `MedicalAIService` ولا تعرف أي مفتاح خادمي. الأنماط:

- `disabled`: الافتراضي؛ لا يرسل أي سؤال إلى نموذج.
- `platformManaged`: مفتاح المنصة محفوظ في Supabase secrets.
- `openAICompatible`: عنوان وموديل يحددهما الخادم.
- `userProvidedKey`: معطل افتراضيًا؛ عند تمكينه يستخدم المفتاح للجلسة/الطلب فقط ولا يسجله.
- `puterWeb`: معزول لنسخة الويب ولا تعتمد عليه نسخة Android.

تطبق `ai-tutor`:

- مصادقة المستخدم وحصة يومية.
- RAG محدود بنتائج المحتوى المنشور فقط.
- عدم إرسال قاعدة البيانات كاملة.
- إرفاق citations تم التحقق منها خادميًا بدل قبول مراجع مولدة.
- منع التشخيص والوصفات والجرعات الشخصية في prompt الخادمي.
- Streaming عبر Server‑Sent Events.
- تسجيل عدد الرموز والزمن دون حفظ مفتاح المزود.

## الاختبارات

### الويب والبنية

```bash
npm test
npm run lint
npm run typecheck
npm run build:next
```

### Flutter

```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test
```

### Supabase وEdge Functions

```bash
supabase start
supabase db reset
supabase test db
deno fmt --check supabase/functions
deno test --allow-read supabase/functions/tests
```

يشغل `.github/workflows/ci.yml` فحوص التنسيق والتحليل والاختبارات، migrations، Edge Functions، وبناء Android debug وrelease.

## النشر

### لوحة الويب

انشر تطبيق Next.js على مزود يدعم Node/Next أو استخدم مسار Vinext/Cloudflare الموجود. عرّف فقط متغيرات `NEXT_PUBLIC_*` العامة في build الخاص بالمتصفح. لا تضف service role إلى إعدادات الاستضافة العامة.

### Android

```bash
cd mobile
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY \
  --dart-define=AI_PROVIDER_MODE=disabled
```

استخدم Android Keystore محفوظًا في مدير أسرار CI، وفعّل Play App Signing. اختبر حزم GLB والأداء على أجهزة منخفضة ومتوسطة وعالية المواصفات قبل النشر.

### Deep Links

المسارات المخططة:

```text
anatomyatlas://organs/heart
anatomyatlas://diseases/myocardial-infarction
https://app.example.com/organs/heart
```

بعد إنشاء platform runners، أضف intent filters/associated domains إلى إعدادات Android وiOS حسب نطاق الإنتاج.

## النسخ الاحتياطي والاستعادة

- فعّل النسخ الاحتياطي اليومي وPoint‑in‑Time Recovery في مشروع Supabase الإنتاجي.
- نفذ تصديرًا دوريًا مستقلًا للمخطط والبيانات وStorage manifest.
- اختبر الاستعادة في مشروع منفصل قبل اعتبار النسخة صالحة.
- لا تعتمد `content_versions` كبديل لنسخة قاعدة البيانات؛ هو سجل تحرير واستعادة محتوى فقط.
- احتفظ بإصدارات حزم المحتوى السابقة في CDN حتى انتهاء نافذة rollback.

## الأمان والخصوصية

- المفتاح المسموح في العميل هو Supabase publishable key فقط.
- جميع الجداول الخاصة محمية بـ RLS.
- الملاحظات والتقدم والمحادثات مرتبطة بـ `auth.uid()`.
- لا تسجل كلمات مرور أو مفاتيح AI أو نصوص صحية حساسة في analytics/crash reports.
- تخزن العمليات الحساسة في `audit_logs` دون أسرار.
- الملفات تبقى في bucket خاص، ولا تصبح عامة إلا وفق مسار وسياسة نشر واضحة.
- استخدم CSP وتعقيم Markdown/HTML عند إضافة renderer للمحتوى الغني.
- راجع سياسات RLS والـ migrations قبل كل إصدار.

للإبلاغ عن ثغرة، لا تفتح Issue عامة تحتوي تفاصيل استغلال أو أسرار؛ أرسل تقريرًا خاصًا لمالك المستودع مع خطوات إعادة الإنتاج والأثر المتوقع.

## سياسة المساهمة

1. أنشئ فرعًا قصير العمر من `develop`.
2. لا تعدل migration مطبقة؛ أضف migration جديدة قابلة للرجوع أو موثقة الأثر.
3. أضف اختبارات لأي Repository أو RPC أو RLS أو منطق تنزيل جديد.
4. لا تنشر حقيقة طبية دون مرجع واضح ومراجعة طبية.
5. لا ترفع ملفات طبية دون ترخيص وattribution.
6. شغّل جميع الفحوص المحلية قبل Pull Request.
7. استخدم Conventional Commits مثل `feat:`, `fix:`, `test:`, `docs:`.
8. يجب أن يوضح PR: المشكلة، الحل، أثر قاعدة البيانات، أثر Offline، لقطات الواجهة، وخطة الاختبار.
9. تحتاج تغييرات RLS/Auth/AI إلى مراجعة أمنية، وتغييرات الحقائق الطبية إلى `medical_reviewer`.
10. يمنع إدخال أسرار أو بيانات مستخدم حقيقية في commits أو fixtures.

## حالة التنفيذ

المستودع يقدم أساس المرحلة الأولى القابل للتوسع: تطبيق Flutter محلي، قلب ثلاثي الأبعاد مع fallback، بحث عربي/إنجليزي، تنزيلات موثقة، لوحة إدارة كاملة، مخطط Supabase واسع، RLS، مالك محمي، مراجعات وإصدارات وAI adapter آمن. توسيع بقية الأجهزة والأمراض والنماذج يتم عبر لوحة المحتوى والمخطط الحالي دون إعادة تصميم جوهر النظام.

---

**تطوير وبرمجة: معتز العلقمي**
