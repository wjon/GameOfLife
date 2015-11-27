// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"

#define  IMHT 16                  //image height
#define  IMWD 16                  //image width

typedef unsigned char uchar;      //using uchar as shorthand

port p_scl = XS1_PORT_1E;         //interface ports to accelerometer
port p_sda = XS1_PORT_1F;

on tile[0] : in port buttons = XS1_PORT_4E; //port to access xCore-200 buttons
on tile[0] : out port leds = XS1_PORT_4F;   //port to access xCore-200 LEDs

#define FXOS8700EQ_I2C_ADDR 0x1E  //register addresses for accelerometer
#define FXOS8700EQ_XYZ_DATA_CFG_REG 0x0E
#define FXOS8700EQ_CTRL_REG_1 0x2A
#define FXOS8700EQ_DR_STATUS 0x0
#define FXOS8700EQ_OUT_X_MSB 0x1
#define FXOS8700EQ_OUT_X_LSB 0x2
#define FXOS8700EQ_OUT_Y_MSB 0x3
#define FXOS8700EQ_OUT_Y_LSB 0x4
#define FXOS8700EQ_OUT_Z_MSB 0x5
#define FXOS8700EQ_OUT_Z_LSB 0x6

/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from PGM file from path infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(char infname[], chanend c_out)
{
  int res;
  uchar line[ IMWD ];
  printf( "DataInStream: Start...\n" );

  //Open PGM file
  res = _openinpgm( infname, IMWD, IMHT );
  if( res ) {
    printf( "DataInStream: Error openening %s\n.", infname );
    return;
  }

  //Read image line-by-line and send byte by byte to channel c_out
  for( int y = 0; y < IMHT; y++ ) {
    _readinline( line, IMWD );
    for( int x = 0; x < IMWD; x++ ) {
      c_out <: line[ x ];
      printf( "-%4.1d ", line[ x ] ); //show image values
    }
    printf( "\n" );
  }

  //Close PGM image file
  _closeinpgm();
  printf( "DataInStream:Done...\n" );
  return;
}

int livingNeighbours(int grid[IMWD][IMHT], int x, int y)
{
    int total = 0;
    int val;
    val = grid[(((x-1)+IMWD)%IMWD)][(((y-1)+IMHT)%IMHT)];
    if (val == 255) total++;
    val = grid[(((x-1)+IMWD)%IMWD)][y];
    if (val == 255) total++;
    val = grid[x][(((y-1)+IMHT)%IMHT)];
    if (val == 255) total++;
    val = grid[(((x-1)+IMWD)%IMWD)][((y+1)%IMHT)];
    if (val == 255) total++;
    val = grid[((x+1)%IMWD)][(((y-1)+IMHT)%IMHT)];
    if (val == 255) total++;
    val = grid[((x+1)%IMWD)][y];
    if (val == 255) total++;
    val = grid[((x+1)%IMWD)][((y+1)%IMHT)];
    if (val == 255) total++;
    val = grid[x][((y+1)%IMHT)];
    if (val == 255) total++;

    return total;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to implement the game of life
// by farming out parts of the image to worker threads who implement it...
// Currently the function just inverts the image
//
/////////////////////////////////////////////////////////////////////////////////////////
void distributor(chanend c_in, chanend c_out, chanend fromAcc, chanend fromButtons, chanend toTimer)
{
  uchar val;
  int acc = 0;
  int button = 0;
  int iterations = 0;
  int grid[IMWD][IMHT];
  int newGrid[IMWD][IMHT];
  int living = 0;

  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage:Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Waiting for Button Press...\n" );
  //fromAcc :> int value;

  while (button != 14)
  {
        fromButtons :> button;
  }

  leds <: 4;
  //Read in and do something with your image values..
  //This just inverts every pixel, but you should
  //change the image according to the "Game of Life"
  printf( "Processing...\n" );
  for( int y = 0; y < IMHT; y++ ) {   //go through all lines
    for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
      c_in :> val;
      grid[x][y] = val;                    //read the pixel value
      //c_out <: (uchar)( val ^ 0xFF ); //send some modified pixel out
    }
  }
  leds <: 0;
  printf( "\nFinished Reading File...\n" );
  toTimer <: 1;
  while(1)
  {
  select {
      case fromButtons :> button: // Check if button is pressed
          if(button == 13) {
              c_out <: 1;
              leds <: 2;
              for( int y = 0; y < IMHT; y++ ) {   //go through all lines
                  for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
                      val = grid[x][y];
                      c_out <: val; //send some modified pixel out
                  }
              }
              leds <: 0;
          }
          break;
      case fromAcc :> acc:
          printf("Paused..\n");
          leds <: 8;
          living = 0;
          for (int y = 0; y < IMHT; y++) {
              for (int x = 0; x < IMWD; x++) {
                  val = grid[x][y];
                  if (val == 255) living++;
              }
          }
          toTimer <: 1;
          int time = 0;
          toTimer :> time;
          printf("Rounds completed: %d\n", iterations);
          printf("Live cells: %d\n", living);
          printf("Time elapsed: %d\n", time);
          fromAcc :> acc;
          printf("Unpaused..\n");
          toTimer <: 0;
          leds <: 0;
          break;
      default:
          iterations++;
          //Do work here..
          printf("Start iteration %d\n", iterations);
          for(int y = 0; y < IMHT; y++)
          {
              for (int x = 0; x < IMWD; x++)
              {
                  val = grid[x][y];
                  if(val == 0)
                  {
                      if(livingNeighbours(grid, x, y) == 3)
                      {
                          newGrid[x][y] = 255;
                      } else {
                          newGrid[x][y] = 0;
                      }
                  } else {
                      int lNeighbours = livingNeighbours(grid, x, y);
                      if(lNeighbours < 2 || lNeighbours > 3)
                      {
                          newGrid[x][y] = 0;
                      } else {
                          newGrid[x][y] = 255;
                      }
                  }
              }
          }
          for(int y = 0; y < IMHT; y++)
          {
              for (int x = 0; x < IMWD; x++)
              {
                  grid[x][y] = newGrid[x][y];
              }
          }
          leds <: (iterations % 2);
          break;
      }
  }
}



/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend c_in)
{
  int res;
  uchar line[ IMWD ];

  while(1)
  {
  int start;
  c_in :> start;
  if(start == 1)
  {
      //Open PGM file
      printf( "DataOutStream:Start...\n" );
      res = _openoutpgm( outfname, IMWD, IMHT );
      if( res ) {
          printf( "DataOutStream:Error opening %s\n.", outfname );
          return;
      }

      //Compile each line of the image and write the image line-by-line
      for( int y = 0; y < IMHT; y++ ) {
          for( int x = 0; x < IMWD; x++ ) {
              c_in :> line[ x ];
            }
            _writeoutline( line, IMWD );
          }

          //Close the PGM image
          _closeoutpgm();
          printf( "DataOutStream:Done...\n" );
      }
  }
  return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Initialise and  read accelerometer, send first tilt event to channel
//
/////////////////////////////////////////////////////////////////////////////////////////
void accelerometer(client interface i2c_master_if i2c, chanend toDist) {
  i2c_regop_res_t result;
  char status_data = 0;
  int tilted = 0;

  // Configure FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_XYZ_DATA_CFG_REG, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }
  
  // Enable FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_CTRL_REG_1, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }

  //Probe the accelerometer x-axis forever
  while (1) {

    //check until new accelerometer data is available
    do {
      status_data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_DR_STATUS, result);
    } while (!status_data & 0x08);

    //get new x-axis tilt value
    int x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);

    //send signal to distributor after first tilt
    if (!tilted) {
      if (x>30) {
        tilted = 1 - tilted;
        toDist <: 1;
      }
    } else {
        if (x<5)
        {
            tilted = 1 - tilted;
            toDist <: 0;
        }
    }
  }
}

// Check for button presses
void buttonListener(in port b, chanend toDist) {
  int r;
  while (1) {
    b when pinseq(15)  :> r;    // check that no button is pressed
    b when pinsneq(15) :> r;    // check if some buttons are pressed
    if ((r==13) || (r==14))     // if either button is pressed
    toDist <: r;             // send button pattern to distributor
  }
}

void runningTimer(chanend toDist) {
    timer t;
    unsigned int time;
    const unsigned int period = 100000000;
    t :> time;
    int secsElapsed = 0;
    toDist :> int func;
    while (1)
    {
        select {
            case t when timerafter (time) :> void:
                secsElapsed++;
                time+=period;
                break;
            case toDist :> int func:
                //int pausedSecs = secsElapsed;
                if(func == 1)
                {
                   toDist <: secsElapsed;
                }
                toDist :> func;
                t :> time;
                //secsElapsed = pausedSecs;
                break;
        }
    }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Orchestrate concurrent system and start up all threads
//
/////////////////////////////////////////////////////////////////////////////////////////
int main(void) {

  i2c_master_if i2c[1];               //interface to accelerometer

  char infname[] = "test.pgm";     //put your input image path here
  char outfname[] = "testout.pgm"; //put your output image path here
  chan c_inIO, c_outIO, c_control, buttonToDist, timerToDist;    //extend your channel definitions here

  par {
    runningTimer(timerToDist);
    buttonListener(buttons, buttonToDist);  //thread to check for button presses
    i2c_master(i2c, 1, p_scl, p_sda, 10);   //server thread providing accelerometer data
    accelerometer(i2c[0],c_control);        //client thread readitng accelerometer data
    DataInStream(infname, c_inIO);          //thread to read in a PGM image
    DataOutStream(outfname, c_outIO);       //thread to write out a PGM image
    distributor(c_inIO, c_outIO, c_control, buttonToDist, timerToDist);//thread to coordinate work on image
  }

  return 0;
}
