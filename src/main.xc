// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"

#define  IMHT 128                 //image height
#define  IMWD 128                  //image width

#define  SEGMENT_SIZE (IMHT)

typedef unsigned char uchar;      //using uchar as shorthand

on tile[0] : port p_scl = XS1_PORT_1E;         //interface ports to accelerometer
on tile[0] : port p_sda = XS1_PORT_1F;

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
void DataInStream(chanend c_out)
{
  char infname[] = "128x128.pgm";     //put your input image path here
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
      //printf( "-%4.1d ", line[ x ] ); //show image values
    }
    //printf( "\n" );
  }

  //Close PGM image file
  _closeinpgm();
  printf( "DataInStream:Done...\n" );
  return;
}

int livingNeighbours(unsigned int grid[(SEGMENT_SIZE/2)+2][SEGMENT_SIZE+2], int x, int y)
{
    int total = 0;
    int val;
    val = grid[(x-1)][(y-1)];
    if (val == 255) total++;
    val = grid[(x-1)][y];
    if (val == 255) total++;
    val = grid[x][(y-1)];
    if (val == 255) total++;
    val = grid[(x-1)][(y+1)];
    if (val == 255) total++;
    val = grid[(x+1)][(y-1)];
    if (val == 255) total++;
    val = grid[(x+1)][y];
    if (val == 255) total++;
    val = grid[(x+1)][((y+1))];
    if (val == 255) total++;
    val = grid[x][(y+1)];
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
void distributor(chanend c_in, chanend c_out, chanend fromAcc, chanend fromButtons, chanend toTimer, chanend toWorker1, chanend toWorker2)
{
  uchar val;
  uchar val2;
  int acc = 0;
  int button = 0;
  int iterations = 0;
  unsigned int grid[IMWD][IMHT];
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
      case toWorker1 :> val:
          toWorker2 :> val2;
          if(val != 2 && val2 != 2)
          {
              iterations++;
              grid[0][0] = val;
              for(int y = 0; y < IMHT; y++)
              {
                  for (int x = 0; x < IMWD/2; x++)
                  {

                      if(x == 0 && y == 0) x++;
                      toWorker1 :> val;
                      grid[x][y] = val;
                      toWorker2 :> val;
                      grid[x+(IMWD/2)][y] = val;
                  }
              }
              leds <: (iterations % 2);
          } else {
          //Do work here..
              int ny,nx;
              for(int y = -1; y < IMHT+1; y++)
              {
                  for (int x = -1; x < (IMWD/2)+1; x++)
                  {
                      //Worker1
                      nx=x;
                      ny=y;
                      if(ny == -1) ny=IMHT-1;
                      if(nx == -1) nx=IMWD-1;
                      if(ny == IMHT) ny = 0;
                      if(nx == IMWD) nx = 0;
                      val = grid[nx][ny];
                      toWorker1 <: val;
                      //Worker2
                      nx=x+(IMWD/2);
                      ny=y;
                      if(ny == -1) ny=IMHT-1;
                      if(nx == -1) nx=IMWD-1;
                      if(ny == IMHT) ny = 0;
                      if(nx == IMWD) nx = 0;
                      val = grid[nx][ny];
                      toWorker2 <: val;
                  }
              }
          }
          break;
      }
  }
}

void worker1(chanend fromDist)
{
    int y_dimension = SEGMENT_SIZE+2;
    int x_dimension = (SEGMENT_SIZE/2)+2;
    unsigned int grid[(SEGMENT_SIZE/2)+2][SEGMENT_SIZE+2];
    unsigned int newGrid[(SEGMENT_SIZE/2)][SEGMENT_SIZE];
    uchar val;
    while(1)
    {
        val = 2;
        fromDist <: val;
        for(int y = 0; y < y_dimension; y++)
        {
            for(int x = 0; x < x_dimension; x++)
            {
                fromDist :> val;
                grid[x][y] = val;

            }
        }
        for(int y = 1; y < y_dimension-1; y++)
        {
            for (int x = 1; x < x_dimension-1; x++)
            {

                val = grid[x][y];
                if(val == 0)
                {
                    if(livingNeighbours(grid, x, y) == 3)
                    {
                        newGrid[x-1][y-1] = 255;
                    } else {
                        newGrid[x-1][y-1] = 0;
                    }
                } else {
                    int lNeighbours = livingNeighbours(grid, x, y);
                    if(lNeighbours < 2 || lNeighbours > 3)
                    {
                        newGrid[x-1][y-1] = 0;
                    } else {
                        newGrid[x-1][y-1] = 255;
                    }
                }
            }
        }
        for(int y = 0; y < y_dimension-2; y++)
            {

                for(int x = 0; x < x_dimension-2; x++)
                {
                    val = newGrid[x][y];
                    fromDist <: val;

                }
            }

    }

}

void worker2(chanend fromDist)
{   int y_dimension = SEGMENT_SIZE+2;
    int x_dimension = (SEGMENT_SIZE/2)+2;
    unsigned int grid[(SEGMENT_SIZE/2)+2][SEGMENT_SIZE+2];
    unsigned int newGrid[(SEGMENT_SIZE/2)][SEGMENT_SIZE];
    uchar val;
    while(1)
    {
        val = 2;
        fromDist <: val;
        for(int y = 0; y < y_dimension; y++)
        {
            for(int x = 0; x < x_dimension; x++)
            {
                fromDist :> val;
                grid[x][y] = val;

            }
        }
        for(int y = 1; y < y_dimension-1; y++)
        {
            for (int x = 1; x < x_dimension-1; x++)
            {

                val = grid[x][y];
                if(val == 0)
                {
                    if(livingNeighbours(grid, x, y) == 3)
                    {
                        newGrid[x-1][y-1] = 255;
                    } else {
                        newGrid[x-1][y-1] = 0;
                    }
                } else {
                    int lNeighbours = livingNeighbours(grid, x, y);
                    if(lNeighbours < 2 || lNeighbours > 3)
                    {
                        newGrid[x-1][y-1] = 0;
                    } else {
                        newGrid[x-1][y-1] = 255;
                    }
                }
            }
        }
        for(int y = 0; y < y_dimension-2; y++)
            {

                for(int x = 0; x < x_dimension-2; x++)
                {
                    val = newGrid[x][y];
                    fromDist <: val;

                }
            }

    }

}
/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(chanend c_in)
{
  char outfname[] = "testout.pgm";
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


  chan c_inIO, c_outIO, c_control, buttonToDist, timerToDist, distToWorker1, distToWorker2;    //extend your channel definitions here

  par {
    on tile[0] : runningTimer(timerToDist);
    on tile[0] : buttonListener(buttons, buttonToDist);  //thread to check for button presses
    on tile[0] : i2c_master(i2c, 1, p_scl, p_sda, 10);   //server thread providing accelerometer data
    on tile[0] : accelerometer(i2c[0],c_control);        //client thread readitng accelerometer data
    on tile[0] : DataInStream(c_inIO);          //thread to read in a PGM image
    on tile[0] : DataOutStream(c_outIO);       //thread to write out a PGM image
    on tile[0] : distributor(c_inIO, c_outIO, c_control, buttonToDist, timerToDist, distToWorker1, distToWorker2);//thread to coordinate work on image
    on tile[0] : worker1(distToWorker1);
    on tile[1] : worker2(distToWorker2);
  }

  return 0;
}
