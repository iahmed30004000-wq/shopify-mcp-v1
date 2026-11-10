// Builds the owner's Word file from prompts.json (the only source of truth).
//
//   node build_docx.js [--style A|B|C] [--out <file.docx>]
//
// Needs the `docx` npm package (v9). If `require('docx')` fails, install it in
// a scratch folder (`npm install docx@9`) and run with NODE_PATH pointing at
// that folder's node_modules.
'use strict';
const fs = require('fs');
const path = require('path');
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, BorderStyle, ShadingType,
  LevelFormat, AlignmentType, PageBreak, Footer, PageNumber,
} = require('docx');

const argv = process.argv.slice(2);
const arg = (name, fallback) => {
  const i = argv.indexOf(`--${name}`);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : fallback;
};

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'prompts.json'), 'utf8'));
const chosen = arg('style', data.recommended_style);
if (!data.styles[chosen]) throw new Error(`unknown style ${chosen}`);
const out = arg('out', path.resolve(`madar-image-prompts-v${data.version}-${chosen}.docx`));

const FONT = 'Arial';
const fonts = { ascii: FONT, hAnsi: FONT, cs: FONT, eastAsia: FONT };
const INK = '2B2620';
const MUTED = '6E6457';
const GOLD = '9A7420';

// Arabic run (right to left). Complex-script size and bold are what Word uses
// for Arabic, so both are always set.
const ar = (text, o = {}) => new TextRun({
  text, rightToLeft: true, font: fonts,
  size: o.size ?? 24, sizeComplexScript: o.size ?? 24,
  bold: o.bold, boldComplexScript: o.bold, color: o.color ?? INK,
});
const en = (text, o = {}) => new TextRun({
  text, font: fonts, size: o.size ?? 21, bold: o.bold, color: o.color ?? INK,
});

const pAr = (runs, o = {}) => new Paragraph({
  bidirectional: true,
  heading: o.heading,
  numbering: o.numbering,
  spacing: { before: o.before ?? 0, after: o.after ?? 120, line: 300 },
  children: (Array.isArray(runs) ? runs : [runs]).map((r) => (typeof r === 'string' ? ar(r, o) : r)),
});

const box = { style: BorderStyle.SINGLE, size: 6, color: 'C9B88A', space: 6 };
const promptPara = (text, last) => new Paragraph({
  shading: { type: ShadingType.CLEAR, fill: 'F6F1E6', color: 'auto' },
  border: { top: box, bottom: box, left: box, right: box },
  spacing: { before: 0, after: last ? 240 : 0, line: 276 },
  children: [en(text)],
});

const rule = () => new Paragraph({
  border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: 'D9CCAA', space: 1 } },
  spacing: { after: 200 },
  children: [],
});

function promptText(p, styleKey) {
  const parts = [p.subject_en, data.sizes[p.size].en];
  if (p.transparent) parts.push(data.transparent_en);
  parts.push(data.styles[styleKey].en, data.rules_en);
  return parts;
}

function promptBlock(code, p, styleKey) {
  const size = data.sizes[p.size];
  const blocks = [
    pAr([ar(`${code}  `, { bold: true, color: GOLD, size: 26 }), ar(p.title_ar, { bold: true, size: 26 })],
      { heading: HeadingLevel.HEADING_3, before: 200, after: 60 }),
    pAr([ar('وين بتنستعمل: ', { bold: true }), ar(p.use_ar)], { after: 40 }),
    pAr([ar('المقاس: ', { bold: true }), ar(`${size.ar} (${size.px})`),
      ar(p.transparent ? '  ·  خلفية شفافة' : '')], { after: 40 }),
    pAr([ar('اسم الملف: ', { bold: true, color: MUTED, size: 22 }), ar(`${code}.png`, { color: MUTED, size: 22 })],
      { after: p.same_chat_ar ? 40 : 100 }),
  ];
  if (p.same_chat_ar) blocks.push(pAr([ar('مهم: ', { bold: true, color: GOLD }), ar(p.same_chat_ar)], { after: 100 }));
  const parts = promptText(p, styleKey);
  parts.forEach((t, i) => blocks.push(promptPara(t, i === parts.length - 1)));
  return blocks;
}

const children = [];
const h1 = (t) => pAr(ar(t, { bold: true, size: 34, color: INK }), { heading: HeadingLevel.HEADING_1, before: 240, after: 160 });
const h2 = (t) => pAr(ar(t, { bold: true, size: 28, color: GOLD }), { heading: HeadingLevel.HEADING_2, before: 240, after: 120 });
const bullet = (t) => pAr(t, { numbering: { reference: 'bullets', level: 0 }, after: 80 });
const step = (t) => pAr(t, { numbering: { reference: 'steps', level: 0 }, after: 80 });

// ---------------------------------------------------------------- cover
const style = data.styles[chosen];
children.push(
  pAr(ar('مدار: برومبتات الصور', { bold: true, size: 48, color: INK }), { heading: HeadingLevel.TITLE, after: 120 }),
  pAr(ar(`نسخة ${data.version}  ·  ${data.updated}  ·  بتنعمل بـChatGPT`, { color: MUTED })),
  pAr([ar('الشكل المكتوب فيه الجولة 2: ', { bold: true }), ar(`${chosen}) ${style.name_ar}`)], { after: 200 }),
  rule(),
  h1('كيف تستعمل الملف'),
  step('افتح ChatGPT وابدأ محادثة جديدة. كل مجموعة صور بمحادثة وحدة، عشان يضلوا من نفس العيلة.'),
  step('انسخ المربع الرمادي كامل (كل الفقرات اللي فيه) والصقه، واستنى الصورة.'),
  step('نزّل الصورة وسمّيها بالاسم المكتوب فوق المربع، مثلاً: R1-A-01.png'),
  step('حطّ الصور بمجلد على Google Drive اسمه «مدار – رسومات»، أو ابعتلي ياهم هون بالشات.'),
  step('إذا طلعت صورة فيها كتابة أو وجه أو إشي غريب، اكتبله: Same image, but remove all text  أو اطلب نسخة ثانية.'),
  pAr([ar('مثال: ', { bold: true, color: GOLD }),
    ar('البرومبت R1-A-01 بيطلعلك خلفية أول شاشة: أسطرلاب نحاسي كبير طاير فوق مدينة زي عمّان وقت المغرب، والكواكب بتلف حواليه.')],
  { before: 80, after: 160 }),
  h1('قواعد ثابتة بكل صورة'),
  bullet('ولا كتابة جوّا الصورة: الذكاء بيخربط الحروف العربية، والكتابة بنحطها إحنا جوّا التطبيق بخط حقيقي.'),
  bullet('ولا وجوه. إذا في ناس، بيكونوا من ظهرهم أو من بعيد، وبلبس محتشم.'),
  bullet('ولا رسمة لنبي أو صحابي أو أي شخصية دينية.'),
  bullet('ولا شعار أو شخصية من لعبة أو فيلم، ولا من GTA نفسها: بناخذ الإحساس بس، والرسم كله أصلي.'),
  bullet('ولا سلاح ولا عنف.'),
  pAr(ar('هالقواعد مكتوبة بالإنجليزي بآخر كل برومبت، فما في داعي تكتبها إنت.', { color: MUTED, size: 22 }), { before: 60 }),
  h1('شو ما بنحتاج له ChatGPT'),
  ...data.not_for_gpt_ar.map(bullet),
);

// ---------------------------------------------------------------- round 1
const r1 = data.rounds.find((r) => r.id === 'R1');
children.push(new Paragraph({ children: [new PageBreak()] }), h1(r1.title_ar), ...r1.intro_ar.map(bullet));
for (const s of r1.styles) {
  const st = data.styles[s];
  const mine = s === data.recommended_style ? '  (اقتراحي)' : '';
  children.push(h2(`الشكل ${s}) ${st.name_ar}${mine}`), pAr(st.about_ar, { after: 160 }));
  for (const p of r1.prompts) {
    if (p.only_styles && !p.only_styles.includes(s)) continue;
    children.push(...promptBlock(`R1-${s}-${p.id}`, p, s));
  }
}

// ---------------------------------------------------------------- round 2
const r2 = data.rounds.find((r) => r.id === 'R2');
children.push(new Paragraph({ children: [new PageBreak()] }), h1(r2.title_ar), ...r2.intro_ar.map(bullet));
for (const g of r2.groups) {
  children.push(h2(g.title_ar), pAr(g.note_ar, { after: 140 }));
  for (const p of g.prompts) children.push(...promptBlock(`R2-${p.id}`, p, chosen));
}

// ---------------------------------------------------------------- log
children.push(new Paragraph({ children: [new PageBreak()] }), h1('سجلّ النسخ'));
for (const l of data.log) children.push(bullet(`نسخة ${l.version}  ·  ${l.date}: ${l.ar}`));

const doc = new Document({
  creator: 'Madar',
  title: 'Madar image prompts',
  styles: {
    default: { document: { run: { font: FONT, size: 24 } } },
    paragraphStyles: [
      { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FONT, size: 34, bold: true }, paragraph: { spacing: { before: 240, after: 160 }, outlineLevel: 0 } },
      { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FONT, size: 28, bold: true }, paragraph: { spacing: { before: 240, after: 120 }, outlineLevel: 1 } },
      { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FONT, size: 26, bold: true }, paragraph: { spacing: { before: 200, after: 60 }, outlineLevel: 2 } },
    ],
  },
  numbering: {
    config: [
      { reference: 'bullets', levels: [{ level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.START,
        style: { paragraph: { indent: { start: 540, hanging: 300 } } } }] },
      { reference: 'steps', levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.START,
        style: { paragraph: { indent: { start: 540, hanging: 360 } } } }] },
    ],
  },
  sections: [{
    properties: { page: { margin: { top: 1134, bottom: 1134, left: 1134, right: 1134 } } },
    footers: {
      default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER,
        children: [new TextRun({ children: [PageNumber.CURRENT], font: fonts, size: 18, color: MUTED })] })] }),
    },
    children,
  }],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(out, buf);
  console.log(`wrote ${out} (${buf.length} bytes)`);
});
