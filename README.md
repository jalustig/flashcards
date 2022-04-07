# FlashCards++ for iOS (archived)

In 2010, I created a flash card program for iOS. I was studying foreign languages for my PhD, and didn't particularly like any of the existing apps. So I created my own. It turned into a major business, generating consistent revenue for over five years. The app is no longer active, and the app store is no longer really lucrative for indie developers (in particular in the flashcards space which is dominated by free apps), so I thought I would share the code. In 2013, I was approached by an ed-tech company with an offer to acquire the app, but I decided at the time to remain in my PhD program rather than switch to tech.

The app would show you a set of flash cards every day, specifically selected based on how well you knew them and how long since you had last studied them. It took your own self-scoring into account to determine the next time that you should study. The system was built to allow a user to grow their list of vocabulary (or any other factual knowledge) at a steady pace.

## The Study Algorithm

FlashCards++ implemented a version of the famous SuperMemo study algorithm, a type of spaced repetition. The theory (which I can attest works from personal experience) is that you remember something more strongly, not if you study it constantly, but if there is a time gap between when you study it at time A, and then the next time when you study it at time B. For each individual card, the application determined an ideal "spacing" between repetitions, which was calculated using an “optimal factor” matrix which took into account how difficult the card was, and the repetition number (e.g. how many times the card had been studied, and recalled correctly).

In the simplest terms, the formula for the optimal spacing interval (i.e. time interval between study repetitions) was: `Optimal Spacing Interval := Optimal_Factors[card_diffiulty, repetition_number] * previous_spacing_interval`. The OF matrix was continually updated with a self-reinforcing algorithm, so that if the previously calculated spacing was too long (i.e. the student could not remember the card), then the card reset to `repetition := 0`, its difficulty was increased, and the OF matrix for cards at that difficulty was decreased (to decrease the future repetition lengths), and it propagated throughout the matrix; similarly, if a card was recalled correctly at the time of studying, then the OF matrix was slightly increased.

Notably, FlashCards++ allowed users to partition their knowledge base into different subjects, where the optimal factor matrix might be different based on the type of knowledge they were studying. For instance, you might have a “collection” of flash cards relating to linear algebra, and a second collection of French vocabulary. Because these cards were so different from one another, the optimal factor matrices of each did not affect each other.

## Features and Technologies Used

I built the app in Objective-C with Core Data, and over time the app matured to use a variety of iOS APIs including in-app purchases as a way to monetize the app.

I also built out sophisticated importing and exporting features to allow users to download flashcards from the internet, back up their data, exchange it with other users, and sync data between their devices.

FlashCards++ was able to search and import data from major flashcards websites including Quizlet, Cram.com, FlashCards Exchange, and more. This would allow users to create their flashcards on their main computer, and then download them to use on their phone.

Additionally, I integrated the app with Dropbox, where users could backup their data.

I also built a number of sync functions. First of all, I implemented a custom API that integrated with Core Data to sync and propagate core data changes across multiple iOS devices. This would allow users to study on their iPhone, and then pick up where they left off on their iPad and vice-versa. Further, I developed an API that would allow users to sync changes in their flashcards with Quizlet’s website. That way, if they edited cards on their phone, those changes would go online; and if they added new cards online they would be automatically downloaded.

While the app began with the interest in studying foreign languages, I worked closely with users and integrated new features that met their needs, including LaTeX support for math equations, adding photos to cards, and text-to-speech.

Additionally, I worked with users around the world who helped translate and internationalize the app for use in French, German, and Russian.
