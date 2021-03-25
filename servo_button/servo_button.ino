#include <Servo.h>

// player buttons
int playerOneUpPin = 2;
int PlayerOneDownPin = 3;
int playerTwoUpPin = 4;
int PlayerTwoDownPin = 5;

// servo positions
float playerOnePos = 90;
float playerTwoPos = 90;
int playerOneCorrected = 0;
int playerTwoCorrected = 0;
int gameMasterPos = 90;

// inputs from serial
String inputString = "";
char inputChar = 'z';

// game state variables
String gameState = "wait";
bool playerOneReady = false;
bool playerTwoReady = false;

// servos
Servo playerOne;
Servo playerTwo;
Servo gameMaster;

void setup() {

  Serial.begin (9600);

  pinMode(playerOneUpPin, INPUT_PULLUP);
  pinMode(PlayerOneDownPin, INPUT_PULLUP);
  pinMode(playerTwoUpPin, INPUT_PULLUP);
  pinMode(PlayerTwoDownPin, INPUT_PULLUP);

  playerOne.attach(9);
  playerTwo.attach(10);
  gameMaster.attach(11);
  
}

void loop() {

  // check gameState to see what we do with button inputs
  if (gameState == "wait") {
    // wait for button presses from players
    if ((digitalRead (playerOneUpPin) == LOW or digitalRead (PlayerOneDownPin) == LOW) and playerOneReady == false) {
      playerOneReady = true;  
      Serial.println("playerOneReady");
    }
    if ((digitalRead (playerTwoUpPin) == LOW or digitalRead (PlayerTwoDownPin) == LOW) and playerTwoReady == false) {
      playerTwoReady = true; 
      Serial.println("playerTwoReady"); 
    }
    // once both players are ready, set gameState to lock and send the ready signal to processing
    if (playerOneReady and playerTwoReady) {
      gameState = "lock";
      //Serial.println("ready");  
    }
  } else if (gameState == "play") {
    // allow players to use the buttons to make answers
   if (digitalRead (playerOneUpPin) == LOW) {
     playerOnePos += 0.05;
   }
   if (digitalRead (PlayerOneDownPin) == LOW) {
     playerOnePos -= 0.05;
   }
    if (digitalRead (playerTwoUpPin) == LOW) {
      playerTwoPos += 0.05;
    }
    if (digitalRead (PlayerTwoDownPin) == LOW) {
      playerTwoPos -= 0.05;
    }
  } else if (gameState == "lock") {
    // do nothing while we show the answers or wait for the question  
  }

  // always update servos, regardless of gameState
  playerOnePos = constrain(playerOnePos, 0, 180);
  playerTwoPos = constrain(playerTwoPos, 0, 180);

  playerOneCorrected = map(playerOnePos, 0, 180, 180, 0);
  playerTwoCorrected = map(playerTwoPos, 0, 180, 180, 0);
  
  playerOne.write(playerOneCorrected);
  playerTwo.write(playerTwoCorrected);

  gameMasterPos = constrain(gameMasterPos, 0, 180);
  gameMaster.write(gameMasterPos);
  
  // read from serial and take actions accordingly
  if (Serial.available() > 0) {
    inputChar = Serial.read();
    switch (inputChar) {
      case 'a':
        // reset all servos
        //Serial.println("Reset");
        playerOnePos = 90;
        playerTwoPos = 90;
        gameMasterPos = 90;
        break;
      case 'b':
        // set gameMaster servo, for showing answers
        //Serial.print("Setting gameMaster to: ");
        gameMasterPos = Serial.parseInt();
        //Serial.println(gameMasterPos);
        break;
      case 'c':
        // returns the positions of both player servos
        Serial.println(String(playerOneCorrected) + ',' + String(playerTwoCorrected));
        break;
      case 'd':
        // sets the gameState to play, unlocking controls
        gameState = "play";
        break;
      case 'e':
        // sets the gameState to lock, locking controls
        gameState = "lock";
        break;
      case 'f':
        // sets the gameState to wait, which waits for players to both press a button
        playerOneReady = false;
        playerTwoReady = false;
        gameState = "wait";
        break;
      default:
        //Serial.println("Unknown starting Byte!");
        break;
    }
  }
}
