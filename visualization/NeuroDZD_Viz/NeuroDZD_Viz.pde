import oscP5.*;
import netP5.*;

// --- CONFIGURATION ---
String dataPath = "PATH/TO/YOUR/DATA/FOLDER/";

// --- CLASS NAMES ---
String[] classNames = {
  "1000DZD", "100DZDP", "10DZDP", "2000DZD", "200DZD", "200DZDP",
  "20DZDP", "500DZD", "50DZDP", "5DZDP", "Not_Money"
};

// --- Currency Conversion ---
float rateUSD = 0.007674; // Fallback rate
float rateEUR = 0.006614; // Fallback rate

// --- State Management ---
enum AppState {
  WAITING, ANIMATING, DISPLAYING_STATIC
}
AppState currentState = AppState.WAITING;

// --- Animation Control ---
int animationPhase = 0;
long phaseStartTime = 0;
int phaseDuration = 1500;
int flattenDuration = 2000;

// --- Camera Control ---
float rotationX = -0.5, rotationY = 0.5, zoomZ = 0, panX = 0, panY = 0;

// --- Global Objects ---
OscP5 oscP5;
PShape inputShape, lowLevelShape, midLevelShape, highLevelShape;

// Data holders
PImage triggeredImage;
float[][][] lowLevelStack, midLevelStack, highLevelStack;
String detectedClassName = "";

ArrayList<MovingBox> movingBoxes = new ArrayList<MovingBox>();

void setup() {
  size(1600, 900, P3D);
  background(0);
  oscP5 = new OscP5(this, 12345);
  textAlign(CENTER, CENTER);
  println("3D Visualizer (Definitive Final Version) is running...");
}

void draw() {
  background(0);

  if (currentState != AppState.WAITING) {
    translate(width/2 + panX, height/2 + panY, zoomZ);
    rotateX(rotationX);
    rotateY(rotationY);
  }

  switch(currentState) {
  case WAITING:
    camera();
    textSize(24);
    fill(200);
    text("WAITING FOR AI SIGNAL...", width/2, height/2);
    break;

  case ANIMATING:
    float currentDuration = (animationPhase == 4) ? flattenDuration : phaseDuration;
    float progress = min((millis() - phaseStartTime) / (float)currentDuration, 1.0);

    if (inputShape != null) shape(inputShape);
    if (animationPhase >= 2 && lowLevelShape != null) shape(lowLevelShape);
    if (animationPhase >= 3 && midLevelShape != null) shape(midLevelShape);
    if (animationPhase >= 4 && highLevelShape != null) shape(highLevelShape);

    for (MovingBox mb : movingBoxes) {
      mb.update(progress);
      mb.display();
    }

    if (progress >= 1.0) {
      animationPhase++;
      phaseStartTime = millis();
      movingBoxes.clear();

      if (animationPhase == 2) createMovingBoxesFromStack(lowLevelStack, 1.5, -250, midLevelStack, 4, -50);
      else if (animationPhase == 3) createMovingBoxesFromStack(midLevelStack, 4, -50, highLevelStack, 8, 100);
      else if (animationPhase == 4) createFlatteningBoxes(highLevelStack, 8, 100);
      else if (animationPhase > 4) currentState = AppState.DISPLAYING_STATIC;
    }
    break;

  case DISPLAYING_STATIC:
    if (inputShape != null) shape(inputShape);
    if (lowLevelShape != null) shape(lowLevelShape);
    if (midLevelShape != null) shape(midLevelShape);
    if (highLevelShape != null) shape(highLevelShape);

    draw3DClassification();
    draw2DClassificationBoxes();
    drawConversionDisplay();
    break;
  }
}

void fetchExchangeRates() {
  thread("fetchExchangeRatesThread");
}

void fetchExchangeRatesThread() {
  println("Fetching latest exchange rates in the background...");
  try {
    JSONObject json = loadJSONObject("https://open.er-api.com/v6/latest/DZD");
    JSONObject rates = json.getJSONObject("rates");
    rateUSD = rates.getFloat("USD");
    rateEUR = rates.getFloat("EUR");
    println("Success! Rates updated. USD: " + rateUSD + ", EUR: " + rateEUR);
  }
  catch (Exception e) {
    println("!!! API Error: Could not fetch rates. Using fallback values.");
  }
}

void oscEvent(OscMessage msg) {
  if (msg.checkAddrPattern("/trigger") && currentState == AppState.WAITING) {
    println("--- Trigger Received! ---");

    fetchExchangeRates();

    println("Building 3D models...");
    detectedClassName = msg.get(0).stringValue();
    animationPhase = 1;
    phaseStartTime = millis();
    movingBoxes.clear();

    triggeredImage = loadImage(dataPath + "input.png");
    lowLevelStack = loadStackedCSV(dataPath + "low_level.csv", 8);
    midLevelStack = loadStackedCSV(dataPath + "mid_level.csv", 8);
    highLevelStack = loadStackedCSV(dataPath + "high_level.csv", 8);

    if (triggeredImage != null) inputShape = buildImageShape(triggeredImage);
    if (lowLevelStack != null) lowLevelShape = buildStackShape(lowLevelStack, 1.5, -250);
    if (midLevelStack != null) midLevelShape = buildStackShape(midLevelStack, 4, -50);
    if (highLevelStack != null) highLevelShape = buildStackShape(highLevelStack, 8, 100);

    createMovingBoxesFromImage(triggeredImage, -500, 1.5, -250);

    println("Models built successfully. Starting animation.");
    currentState = AppState.ANIMATING;
  }
}

void drawConversionDisplay() {
  String denomination = detectedClassName.replaceAll("[^\\d.]", "");
  if (denomination.isEmpty()) return;
  float amountDZD = float(denomination);
  float amountUSD = amountDZD * rateUSD;
  float amountEUR = amountDZD * rateEUR;
  camera();
  hint(DISABLE_DEPTH_TEST);
  float boxWidth = 300;
  float boxHeight = 150;
  float startX = 40;
  float startY = height/2 - boxHeight/2;
  noFill();
  stroke(255, 120);
  strokeWeight(1);
  rect(startX, startY, boxWidth, boxHeight, 7);
  fill(255);
  textAlign(LEFT, TOP);
  textSize(48);
  text(denomination + " DZD", startX + 20, startY + 15);
  fill(255, 200);
  textSize(32);
  text(nf(amountUSD, 0, 2) + " USD", startX + 20, startY + 80);
  text(nf(amountEUR, 0, 2) + " EUR", startX + 20, startY + 115);
  textAlign(CENTER, CENTER);
  hint(ENABLE_DEPTH_TEST);
}
void draw3DClassification() {
  pushMatrix();
  translate(0, 0, 400);
  float boxSize = 25;
  float spacing = 15;
  float totalWidth = classNames.length * (boxSize + spacing) - spacing;
  float startX = -totalWidth/2;
  for (int i = 0; i < classNames.length; i++) {
    pushMatrix();
    float currentX = startX + i * (boxSize + spacing);
    translate(currentX, 0, 0);
    pushMatrix();
    fill(255, 150);
    textSize(12);
    rotateY(-rotationY);
    rotateX(-rotationX);
    text(classNames[i], 0, boxSize + 15);
    popMatrix();
    if (classNames[i].equals(detectedClassName)) {
      noStroke();
      fill(255);
      box(boxSize);
    } else {
      stroke(255, 80);
      strokeWeight(1);
      noFill();
      box(boxSize);
    }
    popMatrix();
  }
  popMatrix();
}
void draw2DClassificationBoxes() {
  camera();
  hint(DISABLE_DEPTH_TEST);
  float boxWidth = 300;
  float boxHeight = 50;
  float spacing = 10;
  float totalHeight = classNames.length * (boxHeight + spacing) - spacing;
  float startX = width - boxWidth - 40;
  float startY = height/2 - totalHeight/2;
  for (int i = 0; i < classNames.length; i++) {
    float currentY = startY + i * (boxHeight + spacing);
    if (classNames[i].equals(detectedClassName)) {
      fill(255);
      stroke(255);
      strokeWeight(2);
      rect(startX, currentY, boxWidth, boxHeight, 7);
      fill(0);
      textSize(24);
      text(classNames[i], startX + boxWidth/2, currentY + boxHeight/2);
    } else {
      noFill();
      stroke(255, 120);
      strokeWeight(1);
      rect(startX, currentY, boxWidth, boxHeight, 7);
      fill(255, 150);
      textSize(24);
      text(classNames[i], startX + boxWidth/2, currentY + boxHeight/2);
    }
  }
  textSize(20);
  fill(255, 100);
  text("Press [ENTER] to Reset  |  Press [R] to Replay Animation", width/2, height - 50);
  hint(ENABLE_DEPTH_TEST);
}
void keyPressed() {
  if (currentState == AppState.DISPLAYING_STATIC) {
    if (key == ENTER || key == RETURN) {
      currentState = AppState.WAITING;
      println("Resetting to WAITING state.");
    } else if (key == 'r' || key == 'R') {
      println("Replaying animation...");
      animationPhase = 1;
      phaseStartTime = millis();
      movingBoxes.clear();
      createMovingBoxesFromImage(triggeredImage, -500, 1.5, -250);
      currentState = AppState.ANIMATING;
    }
  }
}
class MovingBox {
  PVector startPos, endPos;
  float startSize, endSize;
  float alpha;
  PVector currentPos;
  float currentSize;
  MovingBox(PVector sp, PVector ep, float ss, float es, float a) {
    startPos = sp;
    endPos = ep;
    startSize = ss;
    endSize = es;
    alpha = a;
    currentPos = sp.copy();
    currentSize = ss;
  }
  void update(float progress) {
    currentPos = PVector.lerp(startPos, endPos, progress);
    currentSize = lerp(startSize, endSize, progress);
  }
  void display() {
    pushMatrix();
    translate(currentPos.x, currentPos.y, currentPos.z);
    noStroke();
    fill(255, alpha);
    box(currentSize);
    popMatrix();
  }
}
void createMovingBoxesFromImage(PImage sourceImage, float sourceZ, float targetScale, float targetZ) {
  if (sourceImage == null || lowLevelStack == null) return;
  int skip = 4;
  float startX = -sourceImage.width/2;
  float startY = -sourceImage.height/2;
  int targetDepth = lowLevelStack.length;
  int targetRows = lowLevelStack[0].length;
  int targetCols = lowLevelStack[0][0].length;
  float zSpacing = 4;
  float targetStartX = -targetCols * targetScale / 2;
  float targetStartY = -targetRows * targetScale / 2;
  float targetStartZ = targetZ - targetDepth * zSpacing / 2;
  for (int y = 0; y < sourceImage.height; y += skip) {
    for (int x = 0; x < sourceImage.width; x += skip) {
      float b = brightness(sourceImage.get(x, y));
      if (b > 10) {
        float alpha = map(b, 0, 255, 0, 200);
        PVector startPos = new PVector(startX + x, startY + y, sourceZ);
        float endX = targetStartX + random(targetCols) * targetScale;
        float endY = targetStartY + random(targetRows) * targetScale;
        float endZ = targetStartZ + random(targetDepth) * zSpacing;
        PVector endPos = new PVector(endX, endY, endZ);
        movingBoxes.add(new MovingBox(startPos, endPos, skip, targetScale, alpha));
      }
    }
  }
}
void createMovingBoxesFromStack(float[][][] sourceStack, float sourceScale, float sourceZ, float[][][] targetStack, float targetScale, float targetZ) {
  if (sourceStack == null || targetStack == null) return;
  int sourceDepth = sourceStack.length;
  int sourceRows = sourceStack[0].length;
  int sourceCols = sourceStack[0][0].length;
  float sourceZSpacing = 4;
  float sourceStartX = -sourceCols * sourceScale / 2;
  float sourceStartY = -sourceRows * sourceScale / 2;
  float sourceStartZ = sourceZ - sourceDepth * sourceZSpacing / 2;
  int targetDepth = targetStack.length;
  int targetRows = targetStack[0].length;
  int targetCols = targetStack[0][0].length;
  float targetZSpacing = 4;
  float targetStartX = -targetCols * targetScale / 2;
  float targetStartY = -targetRows * targetScale / 2;
  float targetStartZ = targetZ - targetDepth * targetZSpacing / 2;
  float maxVal = 0.0;
  for (int d=0; d<sourceDepth; d++) for (int y=0; y<sourceRows; y++) for (int x=0; x<sourceCols; x++) if (abs(sourceStack[d][y][x]) > maxVal) maxVal = abs(sourceStack[d][y][x]);
  if (maxVal == 0) maxVal = 1.0;
  for (int d = 0; d < sourceDepth; d++) {
    for (int y = 0; y < sourceRows; y++) {
      for (int x = 0; x < sourceCols; x++) {
        float val = sourceStack[d][y][x];
        if (abs(val) > 0.01) {
          float alpha = map(abs(val), 0, maxVal, 50, 255);
          PVector startPos = new PVector(sourceStartX + x*sourceScale, sourceStartY + y*sourceScale, sourceStartZ + d*sourceZSpacing);
          float targetXRatio = (float)x / sourceCols;
          float targetYRatio = (float)y / sourceRows;
          float endX = targetStartX + (targetXRatio * targetCols) * targetScale;
          float endY = targetStartY + (targetYRatio * targetRows) * targetScale;
          float endZ = targetStartZ + d * targetZSpacing;
          PVector endPos = new PVector(endX, endY, endZ);
          movingBoxes.add(new MovingBox(startPos, endPos, sourceScale, targetScale, alpha));
        }
      }
    }
  }
}
void createFlatteningBoxes(float[][][] sourceStack, float sourceScale, float sourceZ) {
  if (sourceStack == null) return;
  int depth = sourceStack.length;
  int rows = sourceStack[0].length;
  int cols = sourceStack[0][0].length;
  float zSpacing = 4;
  float sourceStartX = -cols * sourceScale / 2;
  float sourceStartY = -rows * sourceScale / 2;
  float sourceStartZ = sourceZ - depth * zSpacing / 2;
  int correctClassIndex = -1;
  for (int i = 0; i < classNames.length; i++) if (classNames[i].equals(detectedClassName)) {
    correctClassIndex = i;
    break;
  }
  if (correctClassIndex == -1) return;
  float boxSize = 25;
  float spacing = 15;
  float totalWidth = classNames.length * (boxSize + spacing) - spacing;
  float endX = (-totalWidth/2) + correctClassIndex * (boxSize + spacing);
  float endY = 0;
  float endZ = 400;
  float maxVal = 0.0;
  for (int d=0; d<depth; d++) for (int y=0; y<rows; y++) for (int x=0; x<cols; x++) if (abs(sourceStack[d][y][x]) > maxVal) maxVal = abs(sourceStack[d][y][x]);
  if (maxVal == 0) maxVal = 1.0;
  for (int d = 0; d < depth; d++) {
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        float val = sourceStack[d][y][x];
        if (abs(val) > 0.01) {
          float alpha = map(abs(val), 0, maxVal, 50, 255);
          PVector startPos = new PVector(sourceStartX + x*sourceScale, sourceStartY + y*sourceScale, sourceStartZ + d*zSpacing);
          PVector endPos = new PVector(endX, endY, endZ);
          movingBoxes.add(new MovingBox(startPos, endPos, sourceScale, 1, alpha));
        }
      }
    }
  }
}
void mouseDragged() {
  if (currentState != AppState.WAITING) {
    if (mouseButton == LEFT) {
      panX += (mouseX - pmouseX);
      panY += (mouseY - pmouseY);
    } else if (mouseButton == RIGHT) {
      rotationY += (mouseX - pmouseX) * 0.01;
      rotationX -= (mouseY - pmouseY) * 0.01;
    }
  }
}
void mouseWheel(MouseEvent event) {
  if (currentState != AppState.WAITING) {
    float e = event.getCount();
    zoomZ -= e * 20;
  }
}
PShape buildImageShape(PImage img) {
  PShape group = createShape(GROUP);
  PShape grid = createShape();
  grid.beginShape(LINES);
  grid.stroke(255, 30);
  grid.strokeWeight(1);
  PShape fills = createShape();
  fills.beginShape(QUADS);
  fills.noStroke();
  float startX = -img.width/2;
  float startY = -img.height/2;
  float zPos = -500;
  int skip = 4;
  for (int y = 0; y < img.height; y += skip) {
    for (int x = 0; x < img.width; x += skip) {
      addBoxVertices(grid, startX + x, startY + y, zPos, skip, skip, 1, false);
      float b = brightness(img.get(x, y));
      if (b > 10) {
        float alpha = map(b, 0, 255, 0, 200);
        fills.fill(255, alpha);
        addBoxVertices(fills, startX + x, startY + y, zPos + 1, skip, skip, 1, true);
      }
    }
  }
  grid.endShape();
  fills.endShape();
  group.addChild(grid);
  group.addChild(fills);
  return group;
}
PShape buildStackShape(float[][][] fMapStack, float scaleFactor, float zPos) {
  PShape group = createShape(GROUP);
  PShape grid = createShape();
  grid.beginShape(LINES);
  grid.stroke(255, 30);
  grid.strokeWeight(1);
  PShape fills = createShape();
  fills.beginShape(QUADS);
  fills.noStroke();
  int depth = fMapStack.length;
  int rows = fMapStack[0].length;
  int cols = fMapStack[0][0].length;
  float zSpacing = 4;
  float startX = -cols * scaleFactor / 2;
  float startY = -rows * scaleFactor / 2;
  float startZ = zPos - depth * zSpacing / 2;
  float maxVal = 0.0;
  for (int d = 0; d < depth; d++) {
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        if (abs(fMapStack[d][y][x]) > maxVal) {
          maxVal = abs(fMapStack[d][y][x]);
        }
      }
    }
  }
  if (maxVal == 0) maxVal = 1.0;
  for (int d = 0; d < depth; d++) {
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        float currentZ = startZ + d * zSpacing;
        addBoxVertices(grid, startX + x*scaleFactor, startY + y*scaleFactor, currentZ, scaleFactor, scaleFactor, 1, false);
        float val = fMapStack[d][y][x];
        if (abs(val) > 0.01) {
          float alpha = map(abs(val), 0, maxVal, 50, 255);
          fills.fill(255, alpha);
          addBoxVertices(fills, startX + x*scaleFactor, startY + y*scaleFactor, currentZ, scaleFactor, scaleFactor, 1, true);
        }
      }
    }
  }
  grid.endShape();
  fills.endShape();
  group.addChild(grid);
  group.addChild(fills);
  return group;
}
void addBoxVertices(PShape s, float x, float y, float z, float w, float h, float d, boolean useFaces) {
  float x1 = x - w/2, x2 = x + w/2;
  float y1 = y - h/2, y2 = y + h/2;
  float z1 = z - d/2, z2 = z + d/2;
  if (useFaces) {
    s.vertex(x1, y1, z2);
    s.vertex(x2, y1, z2);
    s.vertex(x2, y2, z2);
    s.vertex(x1, y2, z2);
    s.vertex(x1, y1, z1);
    s.vertex(x2, y1, z1);
    s.vertex(x2, y2, z1);
    s.vertex(x1, y2, z1);
    s.vertex(x1, y1, z1);
    s.vertex(x1, y1, z2);
    s.vertex(x1, y2, z2);
    s.vertex(x1, y2, z1);
    s.vertex(x2, y1, z1);
    s.vertex(x2, y1, z2);
    s.vertex(x2, y2, z2);
    s.vertex(x2, y2, z1);
    s.vertex(x1, y1, z1);
    s.vertex(x2, y1, z1);
    s.vertex(x2, y1, z2);
    s.vertex(x1, y1, z2);
    s.vertex(x1, y2, z1);
    s.vertex(x2, y2, z1);
    s.vertex(x2, y2, z2);
    s.vertex(x1, y2, z2);
  } else {
    s.vertex(x1, y1, z1);
    s.vertex(x2, y1, z1);
    s.vertex(x2, y1, z1);
    s.vertex(x2, y2, z1);
    s.vertex(x2, y2, z1);
    s.vertex(x1, y2, z1);
    s.vertex(x1, y2, z1);
    s.vertex(x1, y1, z1);
    s.vertex(x1, y1, z2);
    s.vertex(x2, y1, z2);
    s.vertex(x2, y1, z2);
    s.vertex(x2, y2, z2);
    s.vertex(x2, y2, z2);
    s.vertex(x1, y2, z2);
    s.vertex(x1, y2, z2);
    s.vertex(x1, y1, z2);
    s.vertex(x1, y1, z1);
    s.vertex(x1, y1, z2);
    s.vertex(x2, y1, z1);
    s.vertex(x2, y1, z2);
    s.vertex(x2, y2, z1);
    s.vertex(x2, y2, z2);
    s.vertex(x1, y2, z1);
    s.vertex(x1, y2, z2);
  }
}
float[][][] loadStackedCSV(String filename, int numMaps) {
  float[][] tallMap = loadCSV(filename);
  if (tallMap == null) {
    println("ERROR: Could not load stacked CSV: " + filename);
    return null;
  }
  if (tallMap.length == 0) return null;
  int mapHeight = tallMap.length / numMaps;
  int mapWidth = tallMap[0].length;
  float[][][] stack = new float[numMaps][mapHeight][mapWidth];
  for (int d = 0; d < numMaps; d++) {
    for (int y = 0; y < mapHeight; y++) {
      for (int x = 0; x < mapWidth; x++) {
        stack[d][y][x] = tallMap[d * mapHeight + y][x];
      }
    }
  }
  return stack;
}
float[][] loadCSV(String filename) {
  String[] lines = loadStrings(filename);
  if (lines == null) return null;
  int rows = lines.length;
  if (rows == 0) return new float[0][0];
  String[] firstLine = split(lines[0], ',');
  int cols = firstLine.length;
  float[][] data = new float[rows][cols];
  for (int i=0; i < rows; i++) {
    String[] vals = split(lines[i], ',');
    for (int j=0; j < cols; j++) {
      if (j < vals.length && vals[j].length() > 0) {
        data[i][j] = float(vals[j]);
      }
    }
  }
  return data;
}
