# Collocation Analysis of User Actions

## Motivation
We are interested in learning patterns of sequences of events and actions carried out by our users when using our product. Our objective is to understand the prior probabilities of sequences of events, in order to predict the next most likely event given a sequence, and suggest them to our users to drive engagement and better use of the product.

Collocation Analysis is a technique from computational linguistics which estimates the likelihood that sequences of words following each other occur at probability different from chance. We explore collocation analysis as a potential candidate for producing a "next-best action" recommender system, by exploiting the assumption that a sequence of user actions have a linear logic, hence some actions groups of actions tend to co-occur together more or less often than chance.

## Definitions

In Linguistics collocations are considered: 

- Habitual juxtaposition of a particular word with another word or words with a frequency greater than chance (lexico.com).
- Combination of words formed when two or more words are often used together in a way that sounds correct (Cambridge Dictionary).

The backbone measure used to learn collocations is [Pointwise Mutual Information (PMI)](https://en.wikipedia.org/wiki/Pointwise_mutual_information)

- Measure of association used in information theory and statistics. In contrast to mutual information (MI) which builds upon PMI, it refers to single events, whereas MI refers to the average of all possible events.
- The PMI of a pair of outcomes x and y belonging to discrete random variables X and Y quantifies the discrepancy between the probability of their coincidence given their joint distribution and their individual distributions, assuming independence. 

## Resources
- [Normalized (Pointwise) Mutual Information in Collocation Extraction](https://svn.spraakdata.gu.se/repos/gerlof/pub/www/Docs/npmi-pfd.pdf)
- [Distributed Representations of Words and Phrases and their Compositionality / 4. Learning Phrases](https://arxiv.org/pdf/1310.4546.pdf)
- [Unsupervised learning of multi-word verbs](http://web.science.mq.edu.au/~mjohnson/papers/2001/dpb-colloc01.pdf)
- Python Library: [Gensim: Phrase (collocation) detection](https://radimrehurek.com/gensim/models/phrases.html)
- R Library: [Identify and score multi-word expressions](https://quanteda.io/reference/textstat_collocations.html)

## RESULTS
- Although the estimation on collocations tends to be an computationally expensive method when applied to large corpora, especially when extracting n-grams > 4, learning sequences of events with high mutual information values was significantly fast considering the small set of action candidates by our users. 
- Estimating sequences of events even up to 15 in length (i.e. an n-gram of length 15) took ~ 10 - 15 seconds.
- The logic behind the statistics learned by Quanteda for the likelihood of ideomatic n-grams generalizes well to analyzing and evaluating sequences of user actions.
- From the results, we can see that:
   - Actions tend to cluster around product features, hence a user working on an aspect of a task will tend to carry out a following action related to that same task or another task, while the same applies to stories, activities, etc.
   - There appear to be many activities which are carried out in bulk, suchs as:
      - Changing the assignee id of a group of tasks.
      - Changing the due date of a group of stories.
   - Some sequences of actions are also defined by the topology of the product, such as carrying out one activity forces the user to carry out another, for example:
      - Changing the due date of an outcome forces the action of recurrently publishing the outcome.
- Collocations analysis was effective when learned over all user actions across all clients. However, to glean insights on action sequences for a specific client, we would need to have a robust set of data for that client, which is not the case for most of the current instances. 
