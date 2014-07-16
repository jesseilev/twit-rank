
# Communicates with Twitter's API
class TwitterRequestor
    
    require 'curb'
    require 'JSON'

    def initialize
        get_token
    end
    
    # Use cURL to request an authorization token from Twitter
    def get_token
        @auth_token = "Bearer AAAAAAAAAAAAAAAAAAAAAJUHYgAAAAAAIxSOkTgNkFCGF64JEcRybmLwzfQ%3DNPKjR9hpkWoQw64m7HhtJapzMR6qFuaPV0tborof1ElJe9y97z"
    end
    
    # Use cURL to ask Twitter for user's "friends". Return an array with the results
    def request_leaders(uid)
        url = "https://api.twitter.com/1.1/friends/ids.json?cursor=-1&id=#{uid}"
        response = send_request(url)
        leaders = response['ids']
        leaders = [] if leaders.nil? || leaders.empty?
        leaders
    end
    
    # Use cURL to ask Twitter for user's "followers". Return an array with the results
    def request_followers(uid)
        url = "https://api.twitter.com/1.1/followers/ids.json?cursor=-1&id=#{uid}"
        response = send_request(url)
        followers = response['ids']
        followers = [] if followers.nil? || followers.empty?
        followers
    end
    
    # Use cURL to request and return the screen_name associated with an id number
    def request_screen_name(uid)
        url = "https://api.twitter.com/1.1/users/show.json?user_id=#{uid}"
        response = send_request(url)
        name = response['screen_name']
        name
    end
    
    # Use cURL to request and return the id number associated with a screen_name
    def request_uid(screen_name)
        url = "https://api.twitter.com/1.1/users/show.json?screen_name=#{screen_name}"
        response = send_request(url)
        uid = response['id']
        uid
    end
    
    private
    
    def send_request(url)
        c = Curl::Easy.perform(url) do |curl|
            curl.headers["Authorization"] = @auth_token
        end
        response = JSON.parse(c.body_str)
        response
    end
end

# A representation of a Twitter user
class User
    
    def initialize( screen_name, uid )
        @screen_name = screen_name
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
        
        puts self.screen_name + ' follows ' + other_user.screen_name + ' .'
        self.leaders << other_user.uid
        other_user.followers << self.uid
    end
    
    def screen_name
        @screen_name
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
        puts "#{self.screen_name} #{score_string} (#{old_score_string} was old score)"
    end
    
end

# A connected graph of Users who follow each other. Can run the PageRank algorithm on itself to calculate the twit_rank scores of each User
class TwitterGraph

    def initialize( users )
        # hash :uid => User
        @users = users
        
        # hash :uid => twit_rank
        @scores = {}
        
        prepare_graph
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
    
    def scores
        @scores
    end
    
    private
    
    def prepare_graph
        users.each do |uid, user|
            
            # If a user is not following anybody, then we pretend he is following EVERYBODY. "When calculating PageRank, pages with no outbound links are assumed to link out to all other pages in the collection. Their PageRank scores are therefore divided evenly among all other pages."
            if (user.leaders.count == 0)
                users.each do |uid, new_leader|
                    user.follow(new_leader)
                end
            end
            
            # Give everyone a baseline score
            user.twit_rank = 1.0 / Float(users.keys.count)
        end
    end
    
end


# Provides convenience contructors for creating a TwitterGraph in a variety of ways
class GraphConstructor
    
    require 'set'

    def initialize
    end
    
    # Creates and returns a graph of real Users that includes the User whose .screen_name == seed_screen_name. This method uses randomness to build its set of Users, so even when you provide the same parameters, the exact set of Users will vary each time.
    def graph_with_initial_screen_name(seed_screen_name, graph_size)
        users = {}
        uids_hash = {}
        followers_hash = {}
        leaders_hash = {}
        
        requestor = TwitterRequestor.new
        seed_uid = requestor.request_uid(seed_screen_name)
        seed_user = User.new( seed_screen_name, seed_uid)
        users[seed_uid] = seed_user
        followers_hash[seed_user.uid] = requestor.request_followers(seed_user.uid)
        leaders_hash[seed_user.uid] = requestor.request_leaders(seed_user.uid)
        puts "Seed user has #{followers_hash[seed_user.uid].count} followers and #{leaders_hash[seed_user.uid].count} leaders"
        while (users.keys.count < graph_size) do
            
            # Choose a random User from our current set
            rand_user = users[users.keys.sample]
            
            # Choose a random "graph edge" from among rand_user's followers and leaders
            followers = followers_hash[rand_user.uid]
            leaders = leaders_hash[rand_user.uid]
            possible_connections = (followers << leaders).flatten
            possible_connections = possible_connections.to_set.to_a #Eliminate duplicates by converting to a Set (and then back to an Array).
            puts "There are #{possible_connections.count} possible connections from #{rand_user.screen_name}"
            rand_connection = possible_connections.sample
            
            # If this follower/leader does not already belong to our current set,
            if ( rand_connection != nil ) and ( !users.keys.include?(rand_connection) )
                # ...then we add him
                new_user_name = requestor.request_screen_name(rand_connection)
                puts 'Adding screen_name ' + new_user_name
                new_user = User.new(new_user_name, rand_connection)
                users[new_user.uid] = new_user
                
                # And with the introduction of a new User, we must connect any new graph edges
                new_user_followers = requestor.request_followers(new_user.uid)
                new_user_leaders = requestor.request_leaders(new_user.uid)
                
                new_user_followers.each do |follower_uid|
                    if users.keys.include?(follower_uid)
                        follower = users[follower_uid]
                        follower.follow(new_user)
                    end
                end
                new_user_leaders.each do |leader_uid|
                    if users.keys.include?(leader_uid)
                        leader = users[leader_uid]
                        new_user.follow leader
                    end
                end
                
                followers_hash[new_user.uid] = new_user_followers
                leaders_hash[new_user.uid] = new_user_leaders
            end
        end
        return TwitterGraph.new(users)
    end
    
    def graph_from_file(filename)
        #TODO
    end
    
    # Creates and returns a TwitterGraph with FAKE Users. You provide a Hash of invented Users and their leaders, of the form  { :user_name => names_of_this_person's_leaders[] }. Each User's .uid will be generated automatically.
    def graph_with_fake_users(leaders_hash)
        # Generate a set of User objects that follow each other as specified by leaders_hash
        users = {}
        uids_hash = {}
        # Iterate twice over @leaders_hash
        # First time, create all the users
        next_uid = 0
        leaders_hash.keys.each do |screen_name, leaders|
            new_user = User.new(screen_name, next_uid)
            users[next_uid] = new_user
            uids_hash[new_user.screen_name] = new_user.uid
            
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
    
    def wikipedia_example
        return {
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
    end
    
end

puts 'Give me an initial user name. (Omit the "@" sign.)'
initial_screen_name = gets.chomp
requestor = TwitterRequestor.new
initial_uid = requestor.request_uid(initial_screen_name)
official_name = requestor.request_screen_name(initial_uid)
followers = requestor.request_followers(initial_uid)
leaders = requestor.request_leaders(initial_uid)

puts 'Constructing graph ---------------------------------------------------------------'
graph_constructor = GraphConstructor.new
#twitter_graph = graph_constructor.graph_with_fake_users(graph_constructor.wikipedia_example)
twitter_graph = graph_constructor.graph_with_initial_screen_name(initial_screen_name, 10)
puts 'Computing scores ---------------------------------------------------------------'
twitter_graph.compute_scores 35
sorted_scores = twitter_graph.scores.sort_by { |uid, score| score }
combined_score = 0.0
puts 'Final Results -----------------------------------------------------------------'
sorted_scores.each do |uid, score|
    combined_score += score
    user = twitter_graph.users[uid]
    score_string = '%.3f' % score
    puts "#{user.screen_name}: #{score_string} (#{user.followers.count} followers) "
end
puts 'Combined score = ' + combined_score.to_s



