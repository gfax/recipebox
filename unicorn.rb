# Set path to app that will be used to configure unicorn.
@dir = Dir.pwd.to_s + '/'

worker_processes 4
working_directory @dir

timeout 30

# Specify path to socket unicorn listens to, 
# we will use this in our nginx.conf later
listen @dir + 'unicorn.sock', :backlog => 64

# Set process id path
pid @dir + 'unicorn.pid'

# Set log file paths
#stderr_path 'log/unicorn.stderr.log'
#stdout_path 'log/unicorn.stdout.log'
