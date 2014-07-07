

# Fetches data from Twitter using the Twitter API
class TwitterRequestor
    
    def initialize
        get_token
    end
    
    # Use cURL to request an authorization token from Twitter
    def get_token
        
        #TODO
    end
    
    # Use cURL to ask Twitter for user's "friends". Return an array with the results
    def request_leaders(uid)
        
        #TODO
        []
    end
    
    # Use cURL to ask Twitter for user's "followers". Return an array with the results
    def request_followers(uid)
        
        #TODO
        []
    end
    
    # Use cURL to get the username associated with an id number
    def request_username(uid)
        
        #TODO
    end
    
    # Use cURL to get the id number associated with a username
    def request_uid(username)
        
        #TODO
    end
    
end

class User

    def initialize( name, uid )
        puts 'Creating a new user named ' + name
        @name = name
        @uid = uid
        @followers = []
        @leaders = []
        @twit_rank = 0.0
    end
    
    def follow other_user
        if (self.uid == other_user.uid)
            #Can't follow yourself.
            return
        end
        if (self.leaders.include? other_user.uid)
            #Self is already following other_user.
            return
        end
        
        puts self.name + ' has begun following ' + other_user.name + ' .'
        self.leaders << other_user.uid
        other_user.followers << self.uid
    end
    
    def name
        @name
    end
    
    def uid
        @uid
    end
    
    def followers
        @followers
    end
    
    def leaders
        @leaders
    end
    
    def twit_rank
        @twit_rank
    end
    def twit_rank=(score)
        old_score = @twit_rank
        @twit_rank = score
        score_string = '%.3f' % score
        old_score_string = '%.3f' % old_score
        puts 'old score was ' + old_score_string + ' ' + self.name + ' ' + score_string + ' is new score'
    end
    
end

class TwitterGraph

    def initialize( users )
        # hash :uid => User
        @users = users
        
        # hash :uid => twit_rank
        @scores = {}
        
    end
    
    def compute_scores(num_iterations)
        current_iteration = 0
        num_iterations.times do
            puts 'Computing scores. Iteration ' + current_iteration.to_s + '......................................'
            #Compute everyone's score and store it in @scores
            users.each do |uid, user|
                score = 0.0
                
                #Aggregate score from followers' scores
                user.followers.each do |follower_uid|
                    follower = @users[follower_uid]
                    #If my follower has n leaders, I get 1/nth of his score
                    score += follower.twit_rank / Float(follower.leaders.count)
                    
                end
                
                #Apply damping factor to the resulting score
                damping_factor = 0.85
                dampened_score = damping_factor * score
                random_jump = (1.0 - damping_factor) / Float(users.count)
                final_score = dampened_score + random_jump
                
                @scores[uid] = final_score
            end
            
            #Loop through @scores and set everyone's .twit_rank
            @scores.each do |uid, score|
                user = @users[uid]
                user.twit_rank = score
            end
            
            current_iteration = current_iteration + 1
        end
    end
    
    def users
        @users
    end
end


# Provides convenience contructors for creating a TwitterGraph in a variety of ways
class GraphConstructor
    
    def initialize
    end
    
    #You provide a Hash of the form  { :user_name => names_of_this_person's_leaders[] }
    def graph_with_leaders_hash(leaders_hash)
        # Generate a set of User objects that follow each other as specified by leaders_hash
        users = {}
        uids_hash = {}
        # Iterate twice over @leaders_hash
        # First time, create all the users
        next_uid = 0
        leaders_hash.keys.each do |name, leaders|
            new_user = User.new(name, next_uid)
            users[next_uid] = new_user
            uids_hash[new_user.name] = new_user.uid
            
            new_user.twit_rank = 1.0 / Float(leaders_hash.keys.count)
            
            next_uid += 1
        end
            
        # Second time, make them follow each other
        leaders_hash.each do |follower_name, leaders|
            follower = users[uids_hash[follower_name]]
            leaders.each do |leader_name|
                leader = users[uids_hash[leader_name]]
                follower.follow leader
            end
            #If a user is not following anybody, then we pretend he is following EVERYBODY. "When calculating PageRank, pages with no outbound links are assumed to link out to all other pages in the collection. Their PageRank scores are therefore divided evenly among all other pages."
            if (leaders.count == 0)
                users.each do |uid, user|
                    follower.follow user
                end
            end
        end
        return TwitterGraph.new(users)
    end
end


wikipedia_example = {
    'A' => [],
    'B' => ['C'],
    'C' => ['B'],
    'D' => ['A', 'B'],
    'E' => ['B', 'D', 'F'],
    'F' => ['B', 'E'],
    'G' => ['B', 'E'],
    'H' => ['B', 'E'],
    'I' => ['B', 'E'],
    'J' => ['E'],
    'K' => ['E']
}

puts 'Give me an initial username. (Omit the "@" sign.)'
initial_username = gets
graph = GraphConstructor.new.graph_with_leaders_hash(wikipedia_example)
graph.compute_scores 35



