#ifndef TILP_H
#define TILP_H

#include <Arduino.h>

class TILP : public Stream {

  private:

    static const int BUFFER_SIZE = 256;

    static const int TIMEOUT_TICK = 4; // in microseconds
    static const int TIMEOUT_INITIAL = 50000; // in ticks, 50000 = 200ms
    static const int TIMEOUT_BIT = 2500; // in ticks, 2500 = 10ms

    int pinD0; // D0 = tip, red
    int pinD1; // D1 = ring, white

    uint8_t bufferIn[TILP::BUFFER_SIZE];
    int bufferInRead = 0;
    int bufferInWrite = 0;
    bool bufferInFull();
    bool bufferInEmpty();

    uint8_t bufferOut[TILP::BUFFER_SIZE];
    int bufferOutRead = 0;
    int bufferOutWrite = 0;
    bool bufferOutFull();
    bool bufferOutEmpty();

    void clearBuffers();

    bool waitReady();
    bool sendRaw(uint8_t value);
    bool getRaw(uint8_t *value);

    void ledOn();
    void ledOff();
    
    bool update();

  public:

    TILP(int pinD0, int pinD1);

    void begin();
    void end();

    virtual int available();
    virtual int read();
    virtual int peek();
    
    using Print::write;
    virtual size_t write(uint8_t value);

    virtual int availableForWrite();
    virtual void flush();
};

#endif