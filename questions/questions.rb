require 'sqlite3'
require 'singleton'

class QuestionsDB < SQLite3::Database
  include Singleton
  
  def initialize
    super('questions.db')
    # self.type_translation = true
    self.results_as_hash = true
  end
end

class Questions2DB < SQLite3::Database
  include Singleton
  
  def initialize 
    super('questions2.db')
    self.results_as_hash = true
  end
end 

class User
  attr_reader :id
  attr_accessor :fname, :lname
  
  def initialize(options)
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end
  
  def self.find_by_name(fname, lname)
    data = QuestionsDB.instance.execute("SELECT * FROM users WHERE fname = #{fname} AND lname = #{lname}")
    people = []
    data.each do |datum|
      person = User.new(datum)
      people << person
    end 
    people 
  end
  
  def authored_questions
    questions = Question.find_by_author_id(@id)
  end
  
  def authored_replies
    replies = Reply.find_by_user_id(@id)  
  end
  
  def self.find_by_id(id)
    user = QuestionsDB.instance.execute(<<-SQL, id)
      SELECT * 
      FROM users
      WHERE id = ?
      SQL
      User.new(user.first)
  end

end

class Question 
  
  attr_reader :id 
  attr_accessor :body, :title, :asso_author
  
  def self.find_by_author_id(author_id)
    questions = QuestionsDB.instance.execute(<<-SQL, author_id)
      SELECT * 
      FROM questions
      WHERE asso_author = ?
      SQL
      result = []
    questions.each do |datum|
      result << Question.new(datum)
    end 
    result
  end 
  
  def self.find_by_question(id)
    data = QuestionsDB.instance.execute("SELECT * FROM questions WHERE id = #{id}").first
    Question.new(data)
  end 
  
  
  def initialize(options)
    @id = options['id']
    @title = options['title']
    @asso_author = options['asso_author']
    @body = options['body']
  end 
  
  def author
    User.find_by_id(@asso_author)
  end
  
  def replies
    Reply.find_by_question_id(@id)
  end
  
end 

class Reply 
  attr_reader :id 
  attr_accessor :question_id, :previous_id, :user_id, :body
  
  
  def self.find_by_id(id)
    data = QuestionsDB.instance.execute(<<-SQL, id)
      SELECT
      *
      FROM 
      replies
      WHERE 
      id = ?
    SQL
    Reply.new(data.first)
  end 
  
  def self.find_by_user_id(user_id)
     data = QuestionsDB.instance.execute(<<-SQL, user_id)
      SELECT 
        *
      FROM 
        replies 
      WHERE 
        user_id = ? 
     SQL
     result = []
     data.each do |datum|
       result << Reply.new(datum)
     end 
     result
  end
  
  def self.find_by_question_id(question_id)
    data = QuestionsDB.instance.execute(<<-SQL, question_id)
      SELECT * 
      FROM replies
      WHERE question_id = ?
    SQL
    
    result = []
    data.each do |datum|
      result << Reply.new(datum)
    end
    result
  end
  
  def initialize(options)
    @id = options['id']
    @question_id = options['question_id']
    @previous_id = options['previous_reply_id']
    @user_id = options['user_id']
    @body = options['body']
  end 
  
  def author
    User.find_by_id(@user_id)
  end
  
  def question 
    Question.find_by_question_id(@question_id)
  end 
  
  def first_reply
    data = QuestionsDB.instance.execute(<<-SQL, @question_id)
      SELECT
        *
      FROM
        replies 
      WHERE 
        question_id = ? AND previous_reply_id IS NULL 
    SQL
    Reply.new(data.first)
  end 
  
  def parent_reply
    raise 'this is the first reply' if @previous_id == nil 
    return Reply.find_by_id(@previous_id)
  end 
  
  def child_replies
    data = QuestionsDB.instance.execute(<<-SQL, @id)
      SELECT
      * 
      FROM 
      replies
      WHERE previous_reply_id = ?
    SQL
    all_replies = []
    data.each do |datum|
      all_replies << Reply.new(datum)
    end 
    all_replies
  end 
  
  
end

class QuestionFollow
  attr_reader :id, :user_id, :question_id
  
  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end
  
  def self.followers_for_question_id(question_id)
    data = Questions2DB.instance.execute(<<-SQL, question_id)
      SELECT *
      FROM question_follows
      JOIN questions ON
      question_follows.question_id = questions.id
      JOIN users ON
      question_follows.user_id = users.id
      WHERE questions.id = ?
    SQL
    result = []
    data.each do |datum|
      result << User.new(datum)
    end
    result
  end
  
  def self.followed_questions_for_user_id(user_id)
    data = Questions2DB.instance.execute(<<-SQL, user_id)
      SELECT *
      FROM question_follows
      JOIN questions ON
      question_follows.user_id = questions.author_id
      JOIN users ON
      question_follows.user_id = users.id
      WHERE users.id = ?
    SQL
    result = []
    data.each do |datum|
    result << Question.new(datum)
  end
  result
  end
  
end
