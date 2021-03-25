import grafica.*;
import processing.serial.*;

// serial set up
Serial myPort; 
String val = "";

//String gameState = "waiting";

boolean playerOneReady = false;
boolean playerTwoReady = false;

// store servo positions
int answerOne = 90;
int answerTwo = 90;

// score positioning
int scoreWidthOffset = 150;
int scoreHeightDefault = 150;
int scoreHeightOne = -60;
int scoreHeightTwo = -60;

// scores
int scoreOne = 0;
int scoreTwo = 0;
int scoreLimit = 3;
int lastWinner = 0;

// timer
float timer = -1;
float frameTime = 0.016;

// how long players have to do things
float askTime = 3;
float questionTime = 15;
float answerTime = 15;
float resultsTime = 10;

//questions stuff
ArrayList<Question> questionsList;
Question currentQuestion;
int questionHeight = 45;

//long text strings
String introText = "Welcome to the CO2 Quiz!\n\nHow to Play:";
String howToPlay = " - The game will show you a graph, and ask a about the\n   CO2 levels in a specific year and city.\n - Use the up and down buttons to turn your dial.\n - Use this to guess the percentage increase or decrease\n   in CO2 levels for given year\n - All the way to the left means there was a 25% decrease,\n   and all the way to the right means there was a 25% increase\n - The center dial with show the real answer\n - The player that is the closest win the round!";

public enum State {
  WAITING, ASKING, QUESTION, ANSWER, RESULTS
}

State gameState = State.WAITING;

void setup()
{
  frameRate(60);
  size(1200, 900);
  background(255);
  // set up the serial port
  //TODO: this is janky as hell, find a better way to do this that will work on other computers
  String portName = Serial.list()[1];
  myPort = new Serial(this, portName, 9600);

  //reset servos
  myPort.write('a');
  //set the board to "waiting for players" mode
  myPort.write('f');
  //prep the questions
  buildQuestionsList();
}

void draw()
{
  // clear the screen
  background(255);

  // tick the timer down
  // the timer is used for the questions countdown, for handling animations, and pretty much everything
  if (timer > 0) {
    timer -= frameTime;
    timer = constrain(timer, 0, 200);
    //println(timer);
  }
  
  // read serial data before drawing a frame, pass the string to the stringCheck function
  if ( myPort.available() > 0) 
  { 
    val = myPort.readStringUntil('\n');
    val = trim(val);
    stringCheck(val);
  }

  //check what mode we're in to run the right display code
  switch(gameState) {
  case WAITING:
    waiting();
    break;
  case ASKING:
    asking();
    break;
  case QUESTION:
    question();
    break;
  case ANSWER:
    answer();
    break;
  case RESULTS:
    results();
    break;
  default:
    break;
  }

  //always draw the score displays
  drawScores();
}

// called every frame while in waiting mode
void waiting() {
  
  //draw the intro text
  fill(0);
  textAlign(CENTER, BOTTOM);
  textSize(25);
  //text(introText, width/2, height/2 - 200);
  
  textAlign(LEFT, BOTTOM);
  text(howToPlay, width/5, height/2 + 150);

  //draw ready up prompts
  drawReady(scoreWidthOffset, scoreHeightDefault);
  drawReady(width - scoreWidthOffset, scoreHeightDefault);

  // move player one score if ready
  if (playerOneReady == true && scoreHeightOne != scoreHeightDefault) {
    float score_lerp = lerp(scoreHeightOne, scoreHeightDefault, 0.05);
    scoreHeightOne = round(score_lerp);
  }
  // move player two score if ready
  if (playerTwoReady == true && scoreHeightTwo != scoreHeightDefault) {
    float score_lerp = lerp(scoreHeightTwo, scoreHeightDefault, 0.05);
    scoreHeightTwo = round(score_lerp);
  }

  // check if we can start
  if (playerOneReady && playerTwoReady) {
    // both players are in, so get ready
    // since the timer doesn't move while negative, we can use it to wait for the join animation to finish
    if (timer == -1) {
      timer = 1;
    } else if (timer == 0) {
      startRound();
    }
  }
}

// called every frame while in asking mode
void asking() {

  //draw the question text
  fill(0);
  textAlign(CENTER, TOP);
  textSize(25);
  text(currentQuestion.question, width/2, questionHeight);

  //display the question
  currentQuestion.drawGraph();

  // once players have had time to read the question, unlock the controls, set the timer, and go to question mode
  if (timer == 0) {
    myPort.write('d');
    timer = questionTime;
    gameState = State.QUESTION;
  }
}

// called every frame while in question mode
void question() {

  //draw the question text
  fill(0);
  textAlign(CENTER, TOP);
  textSize(25);
  text(currentQuestion.question, width/2, questionHeight);

  //display the question
  currentQuestion.drawGraph();

  // Show the timer to the players
  fill(0, 0, 0);
  rectMode(CENTER);
  rect(width/2, height - scoreHeightDefault - 100, map(timer, 0, questionTime, 0, width), 40);

  // when time is up, lock controls, set timer, and move to showing the answer
  if (timer == 0) {
    currentQuestion.addFinalPoint();
    // lock controls
    myPort.write('e');
    timer = answerTime;
    gameState = State.ANSWER;
    //get servo positions and calculate score
    myPort.write('c');
    //show answer!
    myPort.write(str('b') + str(round(map(currentQuestion.correctAnswer, -25, 25, 0, 180))));
  }
}

// called every frame while in answer mode
void answer() {

  //Show winning animation
  if (lastWinner == 1) {
    fill(255, 0, 0);
    circle(width - scoreWidthOffset, height - scoreHeightDefault, timer * 100);
  } else if (lastWinner == 2) {
    fill(0, 0, 255);
    circle(scoreWidthOffset, height - scoreHeightDefault, timer * 100);
  }
  
  //draw the answer text
  fill(0);
  textAlign(CENTER, TOP);
  textSize(25);
  text(currentQuestion.explanation, width/2, questionHeight);

  //display modified graph
  currentQuestion.drawGraph();

  if (timer == 0 && (scoreOne == scoreLimit || scoreTwo == scoreLimit)) {
    timer = resultsTime;
    gameState = State.RESULTS;
  } else if (timer == 0) {
    startRound();
  }
}

// called every frame while in results mode
void results() {
  
  //Show winning animation
  if (lastWinner == 1) {
    fill(255, 0, 0);
    circle(width - scoreWidthOffset, height - scoreHeightDefault, timer * 200);
    fill(0);
    text("Player 1 wins!", width/2, height/2);
  } else if (lastWinner == 2) {
    fill(0, 0, 255);
    circle(scoreWidthOffset, height - scoreHeightDefault, timer * 200);
    fill(0);
    text("Player 2 wins!", width/2, height/2);
  }

  if (timer == 0) {
    //end the game
    resetGame();
  }
}

// debug code that lets me fire things on the ardino via computer keyboard
void keyTyped() {
  // reset the arduino
  if (key == 'f') {
    resetGame();
  } else if (key != 'b') {
    // take commands from the keyboard
    myPort.write(key);
  } else {
    // move gameMaster servo to position 22, for debugging
    myPort.write(str('b') + str(22));
  }
}

//check strings here, so this is only run when there's new serial data
void stringCheck(String check_this) {
  //check for player one being ready
  if (check_this.equals("playerOneReady")) {
    playerOneReady = true;
    //check for player two being ready
  } else if (check_this.equals("playerTwoReady")) {
    playerTwoReady = true;
    // check if we've been sent data from the servos, double checking that there's two values for the array so we don't crash
  } else if (match(check_this, ",") != null) {
    String[] test = splitTokens(check_this, ",");
    answerOne = int(test[0]);
    answerTwo = int(test[1]);
    //calculate scores here, so that it happens after the values have been updated!
    calculateWinner();
  }
  //print to the console for debugging
  println("Checked String: " + check_this);
}

// draws scores
void drawScores() {
  // Render scores
  textAlign(CENTER, BOTTOM);
  textSize(50);
  rectMode(CORNER);

  // player 1
  textSize(50);
  fill(255);
  rect(width - scoreWidthOffset - 120, height - scoreHeightOne - 60, 240, 180, 7);
  fill(255, 0, 0);
  text("Player 1:", width - scoreWidthOffset, height - scoreHeightOne);
  textSize(70);
  text(scoreOne, width - scoreWidthOffset, height - scoreHeightOne + 100);

  // player 2
  textSize(50);
  fill(255);
  rect(scoreWidthOffset - 120, height - scoreHeightTwo - 60, 240, 180, 7);
  fill(0, 0, 255);
  text("Player 2:", scoreWidthOffset, height - scoreHeightTwo);
  textSize(70);
  text(scoreTwo, scoreWidthOffset, height - scoreHeightTwo + 100);
}

// draws the join game text
void drawReady(int x, int y) {
  rectMode(CORNER);
  fill(255);
  rect(x - 120, height - y - 50, 240, 180, 7);
  fill(0);
  textAlign(CENTER, BOTTOM);
  textSize(25);
  text("Press any button" + '\n' + "to join!", x, height - y + 80);
}


// start the game
void startRound() {
  currentQuestion = getQuestion();
  // reset the servos
  myPort.write('a');
  gameState = State.ASKING;
  timer = askTime;
}


// reset the whole game
void resetGame() {
  timer = -1;
  gameState = State.WAITING;
  playerOneReady = false;
  playerTwoReady = false;
  scoreHeightOne = -60;
  scoreHeightTwo = -60;
  scoreOne = 0;
  scoreTwo = 0;
  buildQuestionsList();
  myPort.write('a');
  myPort.write('f');
}

//calculate the winner here, so that we can do it after the serial port has actually been read
void calculateWinner() {
    float playerOneDistance = map(answerOne, 0, 180, 25, -25) - currentQuestion.correctAnswer;
    println("Player 1 is off by: " + playerOneDistance);
    float playerTwoDistance = map(answerTwo, 0, 180, 25, -25) - currentQuestion.correctAnswer;
    println("Player 2 is off by: " + playerTwoDistance);

    if (abs(playerOneDistance) < abs(playerTwoDistance)) {
      //player one won
      scoreOne++;
      lastWinner = 1;
    } else if (abs(playerOneDistance) > abs(playerTwoDistance)) {
      //player two won
      scoreTwo++;
      lastWinner = 2;
    } else {
      // there was a tie, but we'll lie and give someone a point anyways
      println("Tie! A random winner was picked");
      int winner = round(random(1));
      if (winner == 0) {
        scoreOne++;
        lastWinner = 1;
      } else {
        scoreTwo++;
        lastWinner = 2;
      }
    }
}

// get a new question
// only ever call this if there's more than three questions in the list!
Question getQuestion() {

  //Grab a random question, and remove it from the list of questions so we don't repeat this game
  int questionNum = round(random(questionsList.size() - 1));
  Question returnQuestion = questionsList.get(questionNum);
  questionsList.remove(questionNum);
  return returnQuestion;
}

//build/reset the list of questions when a new round starts
void buildQuestionsList() {
  //clear the list
  questionsList = new ArrayList<Question>();
  //add the questions

  //debug questions
  //questionsList.add(new Question(this, "Test Question", new GPointsArray(new float[] {5, 6, 7, 8}, new float[] {22, 19, 35, 20}), new GPoint(9, 21), 15, "Test Explanation"));
  //questionsList.add(new Question(this, "Test Question 2", new GPointsArray(new float[] {21, 22, 23, 24}, new float[] {22, 21, 20, 20}), new GPoint(25, 3), 25, "Test Explanation 2"));
  //questionsList.add(new Question(this, "Test Question 3", new GPointsArray(new float[] {0, 1, 2, 3}, new float[] {0, 0, 6, 7}), new GPoint(4, 21), -25, "Test Explanation 3"));
  
  //real questions
  questionsList.add(new Question(this, "In 2007, China put into place strict regulations on pollution in order to try and\nclear the air for the 2008 Summer Olympics.\nHow much did this effect the CO2 levels in 2009?", new GPointsArray(new float[] {2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008}, new float[] {3405179.867, 3487566.356, 3850269.326, 4540417.061, 5233538.733, 5896957.705, 6529291.518, 6697654.489, 7553070.247}), new GPoint(2009, 7557789.676), 0, "Due to the regulations in place during most of 2008, China managed\nslow rate of CO2 output to an increse of only 0.06%. In late 2008 the restrictions were lifted,\nleading to a 16% increase in 2009."));
  questionsList.add(new Question(this, "In 2010, India introduced a Coal Tax to try and limit the use of burning fossil fuels.\nBy How much did the CO2 levels in India change in as a result 2010?", new GPointsArray(new float[] {2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009}, new float[] {1031853.463, 1041152.975, 1054258.833, 1099597.621, 1154320.262, 1222563.132, 1303717.509, 1407607.286, 1568379.567, 1738645.711}), new GPoint(2010, 1719690.988), -2, "The Coal Tax only managed to reduce the CO2 emisions of India by 2% in the first year,\n with levels continuing to rise in the years following."));
  questionsList.add(new Question(this, "In 2005, France began a climate plan that involved reducing CO2 levels\nby 22% before 2020. How much had they\nreduced their total CO2 emisions by in 2014 compared to 2005?", new GPointsArray(new float[] {2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013}, new float[] {362226.26, 377535.985, 375075.428, 380689.605, 383758.884, 385368.697, 375764.824, 369142.222, 366325.966, 351899.988, 353033.091, 331804.828, 333227.624, 334096.703}), new GPoint(2014, 303275.568), -21, "France managed to reduce their CO2 emisions by 21% in 2014 compared to 2005,\njust 1% off their goal for 2020!"));
  questionsList.add(new Question(this, "In 1989, North Korea's industrial economy had begun to decline.\nAid from the USSR began to dry up in 1990, leading to an almost total\ncollapse of the economy in 1990. How did this effect North Korea's CO2 emisions?", new GPointsArray(new float[] {1980, 1981, 1982, 1983, 1984, 1985, 1986, 1987, 1988, 1989}, new float[] {114439.736, 114799.102, 117344, 125668.09, 135220.625, 144897.838, 157504.984, 176423.037, 201908.687, 214636.844}), new GPoint(1990, 123955.601), -42, "The collapse of North Korea's industrial economy reduced their\nCO2 emisions by 42% in a single year."));
  questionsList.add(new Question(this, "Australia has made a pledge to cut CO2 emisions by 28% by 2030,\ncompared to 2005 levels. By 2016, how much had their emisions\nchanged compared to 2005?", new GPointsArray(new float[] {2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015}, new float[] {329443.28, 324844.862, 341353.696, 336271.234, 342699.485, 350172.831, 365346.877, 372090.49, 385904.079, 394792.887, 390861.863, 391818.95, 388126.281, 372317.844, 361316.844, 365332.209}), new GPoint(2016, 375907.837), 7, "CO2 emisions were up 7% compared to 2005 in 2016, far above\nthe goal of a 28% decrease by 2030. Despite this, 58% of Australians\nconsider climate change as a \"real threat.\""));
  //TODO: Add more questions
  //TODO: make this read from a file instead? This is a really ineligant way of loading in the data
}

//the question class, so that I can call up data related to each question as needed without having to look through arrays of data every time
class Question {

  PApplet game;
  String question; //question text
  GPointsArray data; //an array of points for the graph
  GPoint finalPoint; //the final data point to be added at the end
  GPlot plot; //the graph
  int correctAnswer; //percent change, precomputed
  String explanation; //answer text

  //Question class constructor
  Question(PApplet game, String questionIn, GPointsArray dataIn, GPoint finalPointIn, int answerIn, String explanationIn) {
    question = questionIn;
    data = dataIn;
    finalPoint = finalPointIn;
    correctAnswer = answerIn;
    explanation = explanationIn;
    plot = new GPlot(game, 100, 150, 1000, 500);
    plot.addPoints(data);
  }

  //Draw a graph based on the data this question contains
  void drawGraph() {
    plot.defaultDraw();
  }

  //Adds the final data point before showing the answer
  void addFinalPoint () {
    plot.addPoint(finalPoint);
  }
}
