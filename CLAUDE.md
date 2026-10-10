# Working notes for Claude

## Talking to the owner (standing rule, set by the owner)

Every message to the owner that asks for a **decision** or gives a **report** must be:

1. **100% understandable**: plain Jordanian Arabic, everyday words. No technical terms
   (CI, workflow, commit, snapshot, provider, API, schema …). If a technical word is
   unavoidable, explain it in one short phrase the first time.
2. **With an example**: every decision and every report item gets one concrete example
   from real life or real play (what he will see on his phone, what happens in a real
   card game at home, an amount in JOD …).
3. **Decisions**: think it through properly first, and only ask what truly needs him
   (decide small or rare things myself and say so in one line). For each question:
   - the question in one plain sentence, plus a concrete example;
   - **the best answer / decision FIRST** («✅ اقتراحي»), with a detailed explanation of
     why it is best (what it means in practice, the evidence, an example);
   - then **every other possible option**, each with its own detailed explanation (what
     changes, when it would be better, an example);
   - mark which one the app uses now («المعتمد هلأ»);
   - say how to answer briefly (e.g. «ابعت: 1أ، 2ب»). He chooses; anything he skips
     keeps the current choice.
4. **Reports**: say what changed **for him as a user**, not what the code does, each
   with an example of what he will see. Put what needs him (if anything) at the end.

Example of the right style:

> **سؤال 1: الطرنيب، لما الأربعة يقولوا «باس».**
> مثال: أحمد وزّع، وكل واحد قال «باس». شو بيصير؟
>
> ✅ **اقتراحي: أ) أحمد بيرجع يوزّع من جديد** (المعتمد هلأ)
> ليش: … (شرح مفصّل + مثال)
>
> **باقي الخيارات:**
> ب) التوزيع بينتقل للي بعده: … (شو بيتغيّر، ومتى بيكون أحسن)
> ج) أحمد مجبور يطلب 7 ويلعبها: … (شو بيتغيّر، ومتى بيكون أحسن)
>
> جاوب بحرف وحد، مثلاً: «1ب».

## How to work (standing rule, set by the owner)

- Work **one part at a time**: finish it, verify it, ship an APK, report — then the next part.
- **Save tokens**: no big parallel fan-outs. At most 1–2 agents at a time; do small things directly.
  No duplicate verification passes when CI already runs the same checks.
- Never leave several half-finished things running; stop only at resumable points.

The project itself lives in `madar/` (see `madar/README.md`; while work is paused or
interrupted, `madar/.resume/RESUME.md` says what is in progress and how to resume).
