#include "TILP.h"

TILP::TILP(int pinD0, int pinD1) {
  
  // assign members
  this->pinD0 = pinD0;
  this->pinD1 = pinD1;

  // start immediately
  this->begin();
  
}

void TILP::begin() {
  
  // set both TILP lines to GPIO mode
  pinMode(this->pinD0, FUNCTION_3);
  pinMode(this->pinD1, FUNCTION_3);
  
  // set both TILP lines to be inputs
  pinMode(this->pinD0, INPUT_PULLUP);
  pinMode(this->pinD1, INPUT_PULLUP);

  // clear buffers
  this->clearBuffers();
}

void TILP::end() {

  // return both TILP lines to their origianl mode
  pinMode(this->pinD0, FUNCTION_1);
  pinMode(this->pinD1, FUNCTION_1);

  // clear buffers
  this->clearBuffers();
}

void TILP::clearBuffers() {
  this->bufferInRead = this->bufferInWrite = 0;
  this->bufferOutRead = this->bufferOutWrite = 0;
}

bool TILP::waitReady() {
  int timeout = TILP::TIMEOUT_INITIAL;
  while (!digitalRead(this->pinD0) || !digitalRead(this->pinD1)) {
    delayMicroseconds(TILP::TIMEOUT_TICK);
    if (--timeout == 0) return false;
    yield();
  }
  return true;
}

void TILP::ledOn() {
  if (LED_BUILTIN != this->pinD0 && LED_BUILTIN != this->pinD1) {
    pinMode(LED_BUILTIN, OUTPUT);
  }
}

void TILP::ledOff() {
  if (LED_BUILTIN != this->pinD0 && LED_BUILTIN != this->pinD1) {
    pinMode(LED_BUILTIN, INPUT);
  }
}

bool TILP::sendRaw(uint8_t value) {

  if (!this->waitReady()) return false;
  
  this->ledOn();

  for (int bit = 0; bit < 8; ++bit) {
    
    int timeout = TILP::TIMEOUT_BIT;
    
    if (value & 1) {
      
      // D1 low
      pinMode(this->pinD1, OUTPUT);
      
      // wait for D0 to follow low
      while (digitalRead(this->pinD0)) {
        delayMicroseconds(TILP::TIMEOUT_TICK);
        if (--timeout == 0) goto timeout;
      }
      
      // D1 high
      pinMode(this->pinD1, INPUT_PULLUP);

      // wait for D1 to follow high
      while (!digitalRead(this->pinD0)) {
        delayMicroseconds(TILP::TIMEOUT_TICK);
        if (--timeout == 0) goto timeout;
      }
      
    } else {
      
      // D0 low
      pinMode(this->pinD0, OUTPUT);

      // wait for D1 to follow low
      while (digitalRead(this->pinD1)) {
        delayMicroseconds(TILP::TIMEOUT_TICK);
        if (--timeout == 0) goto timeout;
      }
      
      // D0 high
      pinMode(this->pinD0, INPUT_PULLUP);
      
      // wait for D1 to follow high
      while (!digitalRead(this->pinD1)) {
        delayMicroseconds(TILP::TIMEOUT_TICK);
        if (--timeout == 0) goto timeout;
      }
      
    }
    
    // shift to next bit
    value >>= 1;
    timeout = TILP::TIMEOUT_BIT;
    
    yield();
  }

  this->ledOff();

  return true;

timeout:
  // leave bus idling high before bailing out
  pinMode(this->pinD0, INPUT_PULLUP);
  pinMode(this->pinD1, INPUT_PULLUP);

  this->ledOff();

  return false;
}

bool TILP::getRaw(uint8_t *value) {

  int timeout = TILP::TIMEOUT_INITIAL;

  this->ledOn();

  for (int bit = 0; bit < 8; ) {
    if (!digitalRead(this->pinD0)) {
      
      // D0 low, so it's a 0 bit

      // reply with D1 low
      pinMode(this->pinD1, OUTPUT);

      // shift in a 0 and advance to next bit
      *value >>= 1;
      *value |= 0x00;
      ++bit;
      
      // wait for D0 to return high
      while (!digitalRead(this->pinD0)) {
        delayMicroseconds(TILP::TIMEOUT_TICK);
        if (--timeout == 0) goto timeout;
      }
      
      // reply with D1 high
      pinMode(this->pinD1, INPUT_PULLUP);
      timeout = TILP::TIMEOUT_BIT;

    } else if (!digitalRead(this->pinD1)) {
      
      // D1 low, so it's a 0 bit

      // reply with D0 low
      pinMode(this->pinD0, OUTPUT);
      
      // shift in a 1 and advance to next bit
      *value >>= 1;
      *value |= 0x80;
      ++bit;

      // wait for D1 to return high
      while (!digitalRead(this->pinD1)) {
        delayMicroseconds(TILP::TIMEOUT_TICK);
        if (--timeout == 0) goto timeout;
      }
      
      // reply with D0 high
      pinMode(this->pinD0, INPUT_PULLUP);
      timeout = TILP::TIMEOUT_BIT;
      
    } else {
      
      // nothing happening yet
      delayMicroseconds(TILP::TIMEOUT_TICK);
      if (--timeout == 0) goto timeout;
      if (timeout > TIMEOUT_BIT) yield();

    }
    
    yield();
  }
  
  this->ledOff();

  // return but only mark as successful if the bus has returned to a ready state
  return this->waitReady();

timeout:
  // leave bus idling high before bailing out
  pinMode(this->pinD0, INPUT_PULLUP);
  pinMode(this->pinD1, INPUT_PULLUP);
  
  this->ledOff();
  
  return false;  
}

bool TILP::bufferInEmpty() {
  return this->bufferInRead == this->bufferInWrite;
}

bool TILP::bufferInFull() {
  return ((this->bufferInWrite + 1) % TILP::BUFFER_SIZE) == this->bufferInRead;
}

bool TILP::bufferOutEmpty() {
  return this->bufferOutRead == this->bufferOutWrite;
}

bool TILP::bufferOutFull() {
  return ((this->bufferOutWrite + 1) % TILP::BUFFER_SIZE) == this->bufferOutRead;
}

bool TILP::update() {

  uint8_t value;
  if (!this->bufferInFull() && (!digitalRead(this->pinD0) || !digitalRead(this->pinD1))) {
    if (this->getRaw(&value)) {
      this->bufferIn[this->bufferInWrite] = value;
      if (++this->bufferInWrite == TILP::BUFFER_SIZE) this->bufferInWrite = 0;
      return true;
    }
  } else if (!this->bufferOutEmpty()) {
    value = this->bufferOut[this->bufferOutRead];
    if (this->sendRaw(value)) {
      if (++this->bufferOutRead == TILP::BUFFER_SIZE) this->bufferOutRead = 0;
      return true;
    }
  }

  return false;
}

int TILP::available() {

  while (this->update()) yield();

  int available = this->bufferInWrite - this->bufferInRead;
  while (available < 0) available += TILP::BUFFER_SIZE;
  return available;
}

int TILP::read() {

  while (this->update()) yield();

  if (this->bufferInEmpty()) {
    return -1;
  } else {
    int value = this->bufferIn[this->bufferInRead];
    if (++this->bufferInRead == TILP::BUFFER_SIZE) this->bufferInRead = 0;
    return value;
  }

}

int TILP::peek() {

  while (this->update()) yield();

  if (this->bufferInEmpty()) {
    return -1;
  } else {
    return this->bufferIn[this->bufferInRead];  
  }
}

size_t TILP::write(uint8_t value) {

  while (this->update()) yield();

  if (this->bufferOutFull()) {
    return 0;
  } else {
    this->bufferOut[this->bufferOutWrite] = value;
    if (++this->bufferOutWrite == TILP::BUFFER_SIZE) this->bufferOutWrite = 0;
    return 1;
  }
}

int TILP::availableForWrite() {

  while (this->update()) yield();

  int used = this->bufferOutWrite - this->bufferOutRead;
  while (used < 0) used += TILP::BUFFER_SIZE;
  return TILP::BUFFER_SIZE - used - 1;
  
}

void TILP::flush() {
  while (!this->bufferOutEmpty()) {
    this->update();
    yield();
  }
}