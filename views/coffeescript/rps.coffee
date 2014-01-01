player = prompt "Pick rock, paper, or scissors."

# // // If the player types "ROCK," the script needs to read that the same
# // // as "rock", but only if player !== null!
player = player.toLowerCase() if player?

choices = ["rock","paper","scissors"]
computer = choices[Math.floor(Math.random()*3)]

win = "Your #{player} beats #{computer}. You win."
lose = "Your #{player} loses to #{computer}. Sorry."
draw = "A draw: #{player} on #{computer}."

result = if player is "rock"
           if computer is "scissors"
             win
           else if computer is "paper"
             lose
           else if computer is "rock"
             draw
         else if player is "paper"
           if computer is "rock"
             win
           else if computer is "scissors"
             lose
           else if computer is "paper"
             draw
         else if player is "scissors"
           if computer is "paper"
             win
           else if computer is "rock"
             lose
           else if computer is "scissors"
             draw
         else if player is null
           "Bye!"
         else
           "I said rock, paper, or scissors!"


# // // If the player clicks cancel, the 'result' should equal "Bye!"
# //
# //
# // // If the player enters any other string, 'result' should equal
# // // "I said rock, paper, or scissors!"
# //
# //
# //
alert result
