# Working notes for Claude

## Talking to the owner (standing rule, set by the owner)

Every message to the owner that asks for a **decision** or gives a **report** must be:

1. **100% understandable**: plain Jordanian Arabic, everyday words. No technical terms
   (CI, workflow, commit, snapshot, provider, API, schema …). If a technical word is
   unavoidable, explain it in one short phrase the first time.
2. **With an example**: every decision and every report item gets one concrete example
   from real life or real play (what he will see on his phone, what happens in a real
   card game at home, an amount in JOD …).
3. **Decisions**: say what is being decided in one sentence, give the example, list the
   options as أ / ب / ج, mark the one in use now («المعتمد هلأ») and my recommendation,
   and say how to answer briefly (e.g. «ابعت: 1أ، 2ب»). Anything he skips keeps the
   current choice.
4. **Reports**: say what changed **for him as a user**, not what the code does, each
   with an example of what he will see. Put what needs him (if anything) at the end.

Example of the right style:

> **سؤال: الطرنيب، لما الأربعة يقولوا «باس».**
> مثال: أحمد وزّع، وكل واحد قال «باس». شو بيصير؟
> أ) أحمد بيرجع يوزّع من جديد (المعتمد هلأ)
> ب) التوزيع بينتقل للي بعده
> ج) أحمد مجبور يطلب 7 ويلعبها
> جاوب بحرف وحد، مثلاً: «1ب».

The project itself lives in `madar/` (see `madar/README.md`; while work is paused or
interrupted, `madar/.resume/RESUME.md` says what is in progress and how to resume).
