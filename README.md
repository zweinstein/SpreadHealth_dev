# SpreadHealth_dev
Codes for development of SpreadHealth.tech

1. Collection of Tweets
  * Collected tweets posted from Sep 11 to Sep 25, 2016
  * Limited the scope to tweets about alternative health approaches defined by [60 search keywords](https://github.com/zweinstein/D_I/blob/gh-pages/keywords.txt).
  * Normalized the retweet count by the number of followers for each user
  * Codes are in collectTweets.R (R codes)
 
2. Developing Algorithms
  * Goal: Classification of tweets based on their normalized retweet counts (or retweet frequency, f) into Retweeted (f > 0.5%) and Not Retweeted classes (f <= 0.5%).
  * Tried K-nearest neighbors (KNN), Naive Bayes, and logistic regression, and used Scikit Learn grid search and cross-validation to optimize the parameter set for each method. 
    - Accuracy on a held-out balanced test dataset: 61% for KNN, 71% for Multinomial Naive Bayes, and 75% for logistic regression.
    - Chosen logistic regression as the final model for its higher accuracy and nice probabilistic interpretation.
  * Using "fancier" algorithms such as decision tree models with bagging and boosting (e.g. random forest, XGBoost) may further improve the prediction accuracy/precision/recall. However, I decided to stick with logistic regression, because:
    - I like Occam's Razor principle: only go for a more complicated model if strictly necessary;
    - Logistic regression provides the probability of each tweet belonging to each class. This not only offers intuitive interpretability for the prediction, but also the ability to adjust the classification threshold.
    - Most importantly, logistic regression works really well with online gradient descent method to quickly update the model with new training data (e.g., together with the Flask App), unlike SVM or decision trees.
  * Some more feature engineering is more than likely to improve the prediction, e.g., polarity and sentiment of the tweet.
  * Codes for training the logistic regression with gradient descent and TF-IDF vectorization are in logit_GD.ipynb 
  * Codes for training the logistic regression with online gradient descent method and Hashing Vectorizer are in logit_SGD.ipynb. This is the final model I used for deploying the Flask App.     

3. Deploying the Web App
  * The App is hosted on AWS: [SpreadHealth.tech](spreadhealth.tech)
  * Codes for the Flask App are published in another GitHub [Repo](https://github.com/zweinstein/SpreadHealth)
  * The user types in the tweet draft, and receives the probability for the tweet to be retweeted.
  * The user can provide feedback whether the prediction is correct, which will update an online SQL database to help update the classifier. 
  * If I continue developing the App, more features will be added, including color coding the "good" and "bad" parts of the tweet, make recommendations (e.g., to include certain keywords and mention certain usernames), and user authentication to directly "tweet it" when user is satisfied with predicted retweet probability.
  
  
