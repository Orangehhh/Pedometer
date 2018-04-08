# data analysis
import pandas as pd

# plot tool
import matplotlib.pyplot as plt
import coremltools

# machine learning tools
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.linear_model import LinearRegression
from sklearn.svm import SVC
from sklearn.ensemble import RandomForestClassifier
from sklearn.tree import DecisionTreeClassifier
from sklearn.neighbors import KNeighborsClassifier
from sklearn.naive_bayes import GaussianNB
from sklearn.linear_model import SGDClassifier
from sklearn.neural_network import MLPClassifier
from sklearn.decomposition import PCA



# import the dataset
raw_df = pd.read_csv('../dataset/dataset.csv')

## print some information
# print(raw_df.shape)
# print(raw_df.columns.values)
# print(raw_df.head())
# print(raw_df.tail())
# print(raw_df.info())
# print(raw_df.describe(include=['O']))

# Data pre-processing
# Drop useless column
cleaned_df = raw_df.drop(['username'], axis=1)
cleaned_df = cleaned_df.drop(['date'], axis=1)
cleaned_df = cleaned_df.drop(['time'], axis=1)
# cleaned_df = cleaned_df.drop(['gyro_x'], axis=1)
# cleaned_df = cleaned_df.drop(['gyro_y'], axis=1)
# cleaned_df = cleaned_df.drop(['gyro_z'], axis=1)


X = cleaned_df.drop(['activity'], axis=1)
y = cleaned_df['activity'].copy()
# print(cleaned_df.head())

# PCA visualization
# pca = PCA(n_components=2)
# X_trans = pca.fit(X).transform(X)
# walk = plt.scatter(X_trans[y == 0, 0], X_trans[y == 0, 1], label="walk")
# run = plt.scatter(X_trans[y == 1, 0], X_trans[y == 1, 1], label="run")
# plt.legend((walk, run), ('walk', 'run'))
# plt.title('PCA')
# plt.xlabel('First Component')
# plt.ylabel('Second Component')
# plt.show()

# Model Training
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.1, random_state=0)

# Model 2: Support Vector Machines
svc = SVC()
svc.fit(X_train, y_train)
print("The training accuracy for Support Vector Machines is ", svc.score(X_train, y_train))
print("The testing accuracy for Support Vector Machines is ", svc.score(X_test, y_test))

# print(svc.predict([[0, 0.5595, 7.7488, 0.7232, 0, 0, 0]]))

input_features = ["wrist", "ac_x", "ac_y", "ac_z", "gy_x", "gy_y", "gy_z"]
output_feature = "activity"

model = coremltools.converters.sklearn.convert(svc, input_features, output_feature)
model.save("runOrWalk.mlmodel")