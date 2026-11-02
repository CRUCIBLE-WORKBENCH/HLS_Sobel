/* L1 Sobel magnitude for one complete 3x3 window, saturated to 8 bits. */
unsigned char sobel3x3(unsigned char p0, unsigned char p1, unsigned char p2,
                       unsigned char p3, unsigned char p4, unsigned char p5,
                       unsigned char p6, unsigned char p7, unsigned char p8)
{
    int gx = -(int)p0 + p2 - 2*(int)p3 + 2*(int)p5 - p6 + p8;
    int gy = -(int)p0 - 2*(int)p1 - p2 + p6 + 2*(int)p7 + p8;
    int magnitude = (gx < 0 ? -gx : gx) + (gy < 0 ? -gy : gy);
    (void)p4;
    return magnitude > 255 ? 255 : (unsigned char)magnitude;
}
