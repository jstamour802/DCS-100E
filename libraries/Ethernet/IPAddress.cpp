
//#include <Arduino.h>
#include <IPAddress.h>

IPAddress::IPAddress()
{
    memset(&_address, 0, sizeof(_address));
}

IPAddress::IPAddress(uint8_t first_octet, uint8_t second_octet, uint8_t third_octet, uint8_t fourth_octet)
{
#if 0
    _address[0] = first_octet;
    _address[1] = second_octet;
    _address[2] = third_octet;
    _address[3] = fourth_octet;
#else
    ((uint8_t*)&_address)[0] = first_octet;
    ((uint8_t*)&_address)[1] = second_octet;
    ((uint8_t*)&_address)[2] = third_octet;
    ((uint8_t*)&_address)[3] = fourth_octet;

#endif
}

IPAddress::IPAddress(uint32_t address)
{
    memcpy(&_address, &address, sizeof(_address));
}

IPAddress::IPAddress(const uint8_t *address)
{
	memcpy(&_address, address, sizeof(_address));
}

IPAddress& IPAddress::operator=(const uint8_t *address)
{
	memcpy(&_address, address, sizeof(_address));
    return *this;
}

IPAddress& IPAddress::operator=(uint32_t address)
{
    memcpy(&_address, &address, sizeof(_address));
    return *this;
}

bool IPAddress::operator==(const uint8_t* addr)
{
    return memcmp(addr, &_address, sizeof(_address)) == 0;
}

size_t IPAddress::printTo(Printx& p) const
{
    size_t n = 0;
    for (int i =0; i < 3; i++)
    {
        n += p.print(((uint8_t*)&_address)[i], DEC);
        n += p.print('.');
    }
    n += p.print(((uint8_t*)&_address)[3], DEC);
    return n;
}

