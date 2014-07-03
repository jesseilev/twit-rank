
class User

    def initialize( name, id )
        puts 'Creating a new user named ' + name
        @name = name
        @id = id
        @followers = []
        @leaders = []
        @twit_rank = 0.0
    end
    
    def follow other_user
        if (self.id == other_user.id)
            #Can't follow yourself.
            return
        end
        if (self.leaders.include? other_user.id)
            #Self is already following other_user.
            return
        end
        
        puts self.name + ' has begun following ' + other_user.name + ' .'
        self.leaders << other_user.id
        other_user.followers << self.id
    end
    
    def name
        @name
    end
    
    def id
        @id
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

    def initialize( leaders_hash )
        # hash :id => User
        @users = {}
        
        # hash :id => twit_rank
        @scores = {}
        
        # hash :name => id
        @ids_hash = {}
        
        #Iterate twice over leadersHash
        #First time, create all the users
        next_id = 0
        leaders_hash.keys.each do |name, leaders|
            new_user = User.new(name, next_id)
            @users[next_id] = new_user
            @ids_hash[new_user.name] = new_user.id

            new_user.twit_rank = 1.0 / Float(leaders_hash.keys.count)
            @scores[new_user.id] = new_user.twit_rank
            
            next_id += 1
        end
        
        #Second time, make them follow each other
        leaders_hash.each do |follower_name, leaders|
            follower = @users[@ids_hash[follower_name]]
            leaders.each do |leader_name|
                leader = @users[@ids_hash[leader_name]]
                follower.follow leader
            end
            
            #If a user is not following anybody, then we pretend he is following EVERYBODY. "When calculating PageRank, pages with no outbound links are assumed to link out to all other pages in the collection. Their PageRank scores are therefore divided evenly among all other pages."
            if (leaders.count == 0)
                users.each do |id, user|
                    follower.follow user
                end
            end
        end
        
    end
    
    def compute_scores(num_iterations)
        current_iteration = 0
        num_iterations.times do
            puts 'Computing scores. Iteration ' + current_iteration.to_s + '......................................'
            #Compute everyone's score and store it in @scores
            users.each do |id, user|
                score = 0.0
                
                #Aggregate score from followers' scores
                user.followers.each do |follower_id|
                    follower = @users[follower_id]
                    #If my follower has n leaders, I get 1/nth of his score
                    score += follower.twit_rank / Float(follower.leaders.count)
                    
                end
                
                #Apply damping factor to the resulting score
                damping_factor = 0.99
                dampened_score = damping_factor * score
                random_jump = (1.0 - damping_factor) / Float(users.count)
                final_score = dampened_score + random_jump
                
                @scores[id] = final_score
            end
            
            #Loop through @scores and set everyone's .twit_rank
            @scores.each do |id, score|
                user = @users[id]
                user.twit_rank = score
            end
            
            current_iteration = current_iteration + 1
        end
    end
    
    def users
        @users
    end
end

# For each user, the names of the users he follows
leaders_hash = {
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

graph = TwitterGraph.new(leaders_hash)
graph.compute_scores 85




