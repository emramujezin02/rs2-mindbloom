using Microsoft.EntityFrameworkCore;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Persistence.Seed;

public static class TherapyApproachArticleSeeder
{
    public sealed record EducationalArticle(string Key, string ApproachName, string Title, string Description, string Content);
    public static IReadOnlyList<EducationalArticle> Articles { get; } =
    [
        new("therapy-approach-cbt-v1", "Cognitive Behavioral Therapy", "Understanding Cognitive Behavioral Therapy (CBT)",
            "How thoughts, feelings and behaviour interact, and how CBT explores those patterns.",
            """
            Cognitive Behavioral Therapy (CBT) explores the connections between thoughts, emotions and behaviour. Unhelpful interpretations and learned responses can contribute to difficulties. The therapist and client work collaboratively to understand these patterns and agree on practical goals.

            Sessions may involve examining the evidence for a thought, considering alternative interpretations, practising problem-solving or trying a different response to a difficult situation. Activities between sessions can help the client practise skills in everyday life. The approach usually pays particular attention to current difficulties while also considering relevant personal history.

            CBT is adapted to the person's needs; every session does not use the same techniques. The aim is to develop useful coping skills and greater independence. Choosing an approach should involve a discussion with a qualified professional, rather than an assumption that one method guarantees a particular outcome. This article is an educational introduction, not an individual treatment plan.

            Source: American Psychological Association, What is Cognitive Behavioral Therapy?
            https://www.apa.org/ptsd-guideline/patients-and-families/cognitive-behavioral
            Source checked: 30 October 2026.
            """),
        new("therapy-approach-gestalt-v1", "Gestalt Therapy", "Gestalt Therapy: Awareness in the Present Moment",
            "An introduction to present-moment awareness, dialogue and experience in Gestalt therapy.",
            """
            Gestalt therapy is a humanistic approach that explores a person's present experience. Thoughts, feelings, bodily sensations and relationships are considered together, within the person's current circumstances. Earlier experiences can be discussed through the ways they affect life now.

            A session often involves dialogue and curiosity about what is happening between client and therapist. A therapist may invite attention to a bodily sensation, a feeling or a familiar way of relating to others. Agreed experiments, such as drawing or an empty-chair conversation, can offer another way of exploring an experience. These are possibilities rather than a fixed checklist used with everyone.

            The emphasis is on developing awareness and exploring different responses in a supportive, non-judgmental setting. Therapists bring different styles, so discussing how they work can help a person decide whether the approach suits their preferences. No educational description can predict an individual's outcome or replace a professional assessment.

            Source: British Association for Counselling and Psychotherapy, What is Gestalt therapy?
            https://www.bacp.co.uk/about-therapy/types-of-therapy/gestalt/
            Source checked: 30 October 2026.
            """),
        new("therapy-approach-person-centred-v1", "Person-Centered Therapy", "Person-Centered Therapy: A Supportive Therapeutic Relationship",
            "The role of empathy, acceptance and authenticity in a client-led approach.",
            """
            Person-centered therapy is a humanistic approach associated with Carl Rogers. It places importance on a trusting relationship in which a person can explore their own experiences and choices. The client brings the concerns they wish to discuss, rather than following an agenda imposed by the therapist.

            The therapist aims to offer empathic understanding, acceptance without judgment and authenticity. Listening and reflecting can help the client explore feelings, beliefs, behaviour and personal meaning. The person is treated as knowledgeable about their own experience and supported in recognising their resources and options.

            This approach does not mean that the therapist simply supplies answers or makes decisions for the client. It supports self-awareness and autonomy through the relationship and conversation. What the work looks like depends on the person and their concerns. A discussion with a qualified therapist can clarify expectations and suitability. This overview is educational and does not promise a particular result.

            Source: British Association for Counselling and Psychotherapy, What is person-centred counselling?
            https://www.bacp.co.uk/about-therapy/types-of-therapy/person-centred-counselling/
            Source checked: 30 October 2026.
            """),
        new("therapy-approach-act-v1", "Acceptance and Commitment Therapy", "Acceptance and Commitment Therapy (ACT): Values and Psychological Flexibility",
            "How ACT explores openness to experience and action guided by personal values.",
            """
            Acceptance and Commitment Therapy (ACT) focuses on psychological flexibility: being able to respond to experience while taking action in directions that matter personally. It explores how struggling with or avoiding inner experiences can sometimes narrow a person's choices.

            ACT describes six connected processes: acceptance, cognitive defusion, attention to the present moment, self-as-context, values and committed action. Defusion involves changing one's relationship to thoughts rather than automatically treating them as commands. Values help identify meaningful directions, while committed action involves building behaviour consistent with those directions.

            Work may include conversation, awareness exercises and practical activities chosen for the person's situation. ACT is an orientation rather than one identical protocol for every client. Acceptance is explored alongside meaningful action, not as a promise that difficult feelings will disappear. A qualified professional can discuss how the approach fits an individual's needs. This article offers general education rather than personal treatment advice or guaranteed outcomes.

            Source: Association for Contextual Behavioral Science, About ACT.
            https://contextualscience.org/about_act
            Source checked: 30 October 2026.
            """)
    ];

    public static async Task SeedAsync(ApplicationDbContext context, int authorUserId)
    {
        if (!await context.Users.AnyAsync(x => x.Id == authorUserId))
            throw new InvalidOperationException("A valid existing educational article author is required.");
        foreach (var seed in Articles)
        {
            // Exact seed catalogue identifiers bootstrap the FK once. Runtime
            // navigation never matches titles/names, and subsequent seeds respect edits.
            var approach = await context.TherapyApproaches.SingleOrDefaultAsync(x => !x.IsDeleted && x.Name == seed.ApproachName);
            if (approach == null || !approach.IsActive) continue;
            if (await context.Articles.AnyAsync(x => x.SeedKey == seed.Key)) continue;
            var category = await context.ArticleCategories.SingleOrDefaultAsync(x => !x.IsDeleted && x.Name == "Therapy Approaches");
            if (category == null)
            {
                category = new ArticleCategory { Name = "Therapy Approaches", Description = "Educational introductions to psychotherapy approaches." };
                context.ArticleCategories.Add(category);
            }
            var article = new Article { SeedKey = seed.Key, Title = seed.Title, Description = seed.Description,
                Content = seed.Content, AuthorUserId = authorUserId, ArticleCategory = category,
                IsPublished = true, PublishedAtUtc = new DateTime(2026, 10, 30, 0, 0, 0, DateTimeKind.Utc) };
            context.Articles.Add(article);
            if (!approach.FeaturedArticleId.HasValue) approach.FeaturedArticle = article;
            await context.SaveChangesAsync();
        }
    }
}
