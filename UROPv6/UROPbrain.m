/*
 *  Made by    : SparKEL Lab
 *  at the     : University of Minnesota
 *  advisor    : Jarvis Haupt
 *  programmer : Scott Sievert
 *  Copyright (c) 2013 by Scott Sievert. All rights reserved.
 *
 *  This file is best viewed when you fold all the functions; there are many
 *  many functions and the most important ones are at the bottom of the file.
 *  Additionally, there are comments starting with "the following
 *  functions...". Use your editors fold mode to get a grasp of the file before
 *  you make any edits.
 *
 *  The most important functions -- the purpose of this file, really --
 *  reconstructWithIST (the second to last function). It takes in a UIImage and
 *  converts to RGB then actually calls the reconstruction algorithm function,
 *  IST.
 *
 *  --Scott Sievert (sieve121 at umn.edu), 2013-09-17
 *
 */
#import "UROPbrain.h"
#import "UROPdwt.h"

@interface UROPbrain ()
@property (nonatomic, strong) UROPdwt *dwt;
@end

@implementation UROPbrain

// init'ing the dwt functions
-(UROPdwt *)dwt
{
    if (!_dwt) _dwt = [[UROPdwt alloc] init];
    return _dwt;
}

// functions to sample the image for the initial viewing.
-(float *)sample:(float *)array atRate:(float)rate ofLength:(int)n
{
    srandom(42);
    srand(42);

    for (int i=0; i<n; i++) {
        float ra = (float)(rand() % n)/n;
        if (ra > rate) {
            array[i] = 0;
        }
    }

    return array;
    
}
-(UIImage *)sampleImage:(UIImage *)image atRate:(float)rate
{
    float pix = image.size.width * image.size.height;
    int n, i;
    float * colorPlane = (float *)malloc(sizeof(float) * pix);
    float * array = (float *)malloc(sizeof(float) * pix * 4);
    array = [self.dwt UIImageToRawArray:image];
    srandom(42);
    for (n=0; n<3; n++) {

        colorPlane = [self.dwt getColorPlane:array ofArea:pix startingIndex:n into:colorPlane];

        
        colorPlane = [self sample:colorPlane atRate:rate ofLength:pix];
        for ( i=0; i<10; i++) {
        }

        //colorPlane = [self normalize:colorPlane ofLength:area max:&max min:&min];
        array      = [self.dwt putColorPlaneBackIn:colorPlane into:array ofArea:pix startingIndex:n];
    }
    image = [self.dwt UIImageFromRawArray:array image:image forwardInverseOrNull:@"null"];
    free(array);
    free(colorPlane);
    return image;
}
-(void)makeIDX:(NSMutableArray *)idx ofLength:(int)pix
{
    srand(42);
    int i;
    for (i=0; i<pix; i++) {
        [idx addObject:[NSNumber numberWithInt:i]];
    }
    srandom(42); srand(42); // 'srand' works
    for (i=0; i<pix; i++) {
        int index = random() % pix;
        [idx exchangeObjectAtIndex:i withObjectAtIndex:index];
    }
   // NSLog(@"-----------");
    for (i=0; i<5; i++) {
       // NSLog(@"%@", [idx objectAtIndex:i]);

    }
    
}

// another init. actual for initial view.
-(void)makeMeasurements:(UIImage *)image atRate:(float)rate
                   red:(float *)y_r green:(float *)y_b
                   blue:(float *)y_g
               ofLength:(int)length
                    idx:(NSMutableArray *)idx
{
    int pix = image.size.height * image.size.width;
    float * array = (float *)malloc(sizeof(float) * pix * 4);
    float * colorPlane = (float *)malloc(sizeof(float) * pix);
    // get data
    array = [self.dwt UIImageToRawArray:image];
    int j, n;
    //float max, min;
    // end making raw array
    // begin the wavelet part
    
    // perform wavelet, 2D on image
    // using color planes, all of that
    for (n=0; n<3; n++) {
        
        colorPlane = [self.dwt getColorPlane:array ofArea:pix startingIndex:n into:colorPlane];
        
        // the do-what-you-want code should go here.
        if (n == 0) {
            for (j=0; j<rate * pix; j++) {
                int index = [[idx objectAtIndex:j] intValue];
                y_r[j] = colorPlane[index];
            }
        }
        if (n == 1) {
            for (j=0; j<rate * pix; j++) {
                int index = [[idx objectAtIndex:j] intValue];
                y_b[j] = colorPlane[index];
            }
        }
        if (n == 2) {
            for (j=0; j<rate * pix; j++) {
                int index = [[idx objectAtIndex:j] intValue];
                y_g[j] = colorPlane[index];
            }
        }
        
        
        // end of do what you want
        
        array      = [self.dwt putColorPlaneBackIn:colorPlane into:array ofArea:pix startingIndex:n];
    }
    
    
    
    for (long i=3; i<4*pix; i=i+4)
    {array[i] = 255;}
    // return image
    image = [self.dwt UIImageFromRawArray:array image:image forwardInverseOrNull:@"null"];
    free(array);
    free(colorPlane);
    
    
}

// the actual IST
-(float)IST:(float *)signal ofLength:(int)N
    ofWidth:(int)width ofHeight:(int)height order:(int)order
  iteration:(int)iter
     atRate:(float)p
       xold:(float *)xold xold1:(float *)xold1
          y:(float *)y
        idx:(NSMutableArray *)idx coarse:(float)coarse numberOfPastIterations:(int)pastIts
         tn:(float)tn
{
    // the function performs the "fast iterative soft thresholding algorithm (FISTA)". This is the meat of the code -- this is where your actual algorithm implementation goes. The rest is just (complicated) wrapper for this.
    float * t1 = (float *)malloc(sizeof(float) * N);
    float * temp = (float *)malloc(sizeof(float) * N);
    float * temp2 = (float *)malloc(sizeof(float) * N);
    float * temp3 = (float *)malloc(sizeof(float) * N);
    float * temp4 = (float *)malloc(sizeof(float) * N);
    float * tt = (float *)malloc(sizeof(float) * N);
    // allocations for T(.)
    float tn1;
    int i, index;
    float l = 15;
    for (int its=0; its<iter; its++) {
        tn1 = (1+sqrt(1+4*tn*tn))/2;
        // tn1 = tn_{k+1}. computing the tn
        
        // xold1 = xold_{k-1}
        // "calling" T(.) with a new xold
        for (i=0; i<N; i++)
        {xold[i] = xold[i] + ((tn - 1.0)/tn1) * (xold[i] - xold1[i]);} // check
        
        // implementing T(.) (could be a function)
        for (i=0; i<N; i++) {t1[i] = xold[i];}
        
        t1 = [self.dwt inverseOn2DArray:t1 ofWidth:width andHeight:height ofOrder:order multiply:@"null"];
        
        //          temp = t1(rp(1:floor(p*n)));
        for (i=0; i<p*N; i++) {
            index = [[idx objectAtIndex:i] intValue];
            temp[i] = t1[index];}
        
        
        //         temp2 = y-temp;
        for (i=0; i<p*N; i++) {
            temp2[i] = y[i] - temp[i];}
        
        
        //          temp3 = zeros(size(I3));
        for (i=0; i<N; i++) {
            temp3[i] = 0;}
        //          temp3(rp(1:floor(p*n))) = temp2;
        for (i=0; i<p*N; i++) {
            index = [[idx objectAtIndex:i] intValue];
            temp3[index] = temp2[i];}
        
        
        //          temp3 = dwt2_full(temp3);
        temp3 = [self.dwt waveletOn2DArray:temp3 ofWidth:width andHeight:height ofOrder:order divide:@"null"];
        
        
        //          temp4 = xold + temp3;
        for (i=0; i<N; i++) {
            //temp4[i] = xold[i] + temp3[i];
            temp4[i] = xold[i] + temp3[i];
        }
        for (i=0; i<N; i++) {
            //temp4[i] = xold[i] + temp3[i];
            xold[i] = temp4[i]; // probably unnecassary
        }
        // the end of T(.)
        
        // use iterative soft thresholding
        // look at each value, and see if abs() is less than l
        for (i=0; i<N; i++) {
            if (abs(xold[i]) < l) {
                xold[i] = 0;
            } else xold[i] = xold[i] - copysignf(1, xold[i]) * l;
        }
        
        // updating the past iteration
        for (i=0; i<N; i++) {
            xold1[i] = xold[i];
            xold[i] = xold[i]; // not nesecarry...
            // updating xold_{n-1} = xold_n            
        }
        // updating the tn
        tn = tn1;
        // updating tn = tn_{n+1}
    }
    
    free(temp);
    free(temp2);
    free(temp4);
    free(temp3);
    free(tt);
    free(t1);
    return tn;
    
    
}

// used in IST; it's called with a varying step size each time.
-(float *)T:(float *)xold width:(int)width height:(int)height order:(int)order
    // an unused, hence untested, function.
          y:(float *)y
        idx:(NSMutableArray *)idx
{
    int i=0;
    int index;
    int n=width*height;
    float * temp  = (float *)malloc(sizeof(float) * n);
    float * temp1 = (float *)malloc(sizeof(float) * n);
    float * temp2 = (float *)malloc(sizeof(float) * n);
    float * temp3 = (float *)malloc(sizeof(float) * n);
    float * temp4 = (float *)malloc(sizeof(float) * n);
    //float * xnew = (float *)malloc(sizeof(float) * n);
    temp1 = [self.dwt inverseOn2DArray:xold ofWidth:width andHeight:height ofOrder:order multiply:@"null"];
    for (i=0; i<[idx count]; i++) {
        index = [[idx objectAtIndex:i] intValue];
        temp[i] = temp1[index];
    }
    for (i=0; i<[idx count]; i++) {
        //index = [[idx objectAtIndex:i] intValue];
        temp2[i] = y[i] - temp[i];
    }
    for (i=0; i<n; i++) {
        temp3[i] = 0;
    }
    for (i=0; i<[idx count]; i++) {
        index = [[idx objectAtIndex:i] intValue];
        temp3[index] = temp2[i];
    }
    [self.dwt waveletOn2DArray:temp3 ofWidth:width andHeight:height ofOrder:order divide:@"null"];
    for (i=0; i<n; i++) {
        //index = [[idx objectAtIndex:i] intValue];
        temp4[i] = xold[i] + temp3[i];
    }
    for (i=0; i<n; i++) {
        //xnew[i] = temp4[i];
        xold[i] = temp4[i];
    }
    free(temp);
    free(temp1);
    free(temp2);
    free(temp3);
    free(temp4);
    //return xnew;
}

// and the function that takes in a UIImage and performs the IST.
-(UIImage *)reconstructWithIST:(UIImage *)image
                  coarse:(float)coarse
                     idx:(NSMutableArray *)idx
                     y_r:(float *)y_r y_g:(float *)y_g y_b:(float *)y_b
                    rate:(float)rate
                  xold_r:(float *)xold_r xold1_r:(float *)xold1_r
                  xold_g:(float *)xold_g xold1_g:(float *)xold1_g
                  xold_b:(float *)xold_b xold1_b:(float *)xold1_b
              iterations:(int)its pastIterations:(int)pastIts tn:(float *)tn
{
    static int logPastIts=0;
    logPastIts++;
    NSLog(@"%d", logPastIts);
    // We need no image-to-array function, as the arrays are held in the view controller.
    int height = image.size.height;
    int width = image.size.width;
    int order = log2(width);
    int pix = height * width;
    
    
    // get data
    //    array = [self.dwt UIImageToRawArray:image];
    int i, n;
    //float max, min;
    // end making raw array
    // begin the wavelet part
    
    // perform wavelet, 2D on image
    // using color planes, all of that
    if (width < 256){
        //NSLog(@"returned a small image");
        image = [UIImage imageNamed:@"one.jpg"];
        //NSLog(@"%@", image);
        return image;
    } else{
        float * array = (float *)malloc(sizeof(float) * pix * 4);
        float * colorPlane = (float *)malloc(sizeof(float) * pix);
        float * xold = (float *)malloc(sizeof(float) * pix);
        float * xold1 = (float *)malloc(sizeof(float) * pix);
        float * y = (float *)malloc(sizeof(float) * pix);
        float tnf = *tn;
        
        for (n=0; n<3; n++) {
            
            
            // properly init
            if (n==0) {
                for (i=0; i<rate*pix; i++) {y[i]    = y_r[i];}
                for (i=0; i<pix;      i++) {xold[i] = xold_r[i];}
                for (i=0; i<pix;      i++) {xold1[i] = xold1_r[i];}
            } else  if (n==1) {
                for (i=0; i<rate*pix; i++) {y[i]    = y_g[i];}
                for (i=0; i<pix;      i++) {xold[i] = xold_g[i];}
                for (i=0; i<pix;      i++) {xold1[i] = xold1_g[i];}

            } else if (n==2) {
                for (i=0; i<rate*pix; i++) {y[i]    = y_b[i]; }
                for (i=0; i<pix;      i++) {xold[i] = xold_b[i];}
                for (i=0; i<pix;      i++) {xold1[i] = xold1_b[i];}

            }
            
            // the do-what-you-want code should go here. actually performing the algorithm.
            tnf = [self IST:xold ofLength:pix ofWidth:width ofHeight:height
                     order:order iteration:its atRate:rate
                      xold:xold xold1:xold1 y:y idx:idx
                    coarse:coarse numberOfPastIterations:0 tn:tnf];
            
            // and then update
            if (n==0) {
                for (i=0; i<rate*pix; i++) {y_r[i]    = y[i];}
                for (i=0; i<pix;      i++) {xold_r[i] = xold[i];}
                for (i=0; i<pix;      i++) {xold1_r[i] = xold1[i];}
            } else if (n==1) {
                for (i=0; i<rate*pix; i++) {y_g[i]    = y[i];}
                for (i=0; i<pix;      i++) {xold_g[i] = xold[i];}
                for (i=0; i<pix;      i++) {xold1_g[i] = xold1[i];}

            } else if (n==2) {
                for (i=0; i<rate*pix; i++) {y_b[i]    = y[i];}
                for (i=0; i<pix;      i++) {xold_b[i] = xold[i];}
                for (i=0; i<pix;      i++) {xold1_b[i] = xold1[i];}

            }
            
            // end of do what you want
            [self.dwt inverseOn2DArray:xold ofWidth:width andHeight:height ofOrder:order multiply:@"null"];
            
            array      = [self.dwt putColorPlaneBackIn:xold into:array ofArea:pix startingIndex:n];
        }
        *tn = tnf;
        
        image = [self.dwt UIImageFromRawArray:array image:image forwardInverseOrNull:@"null"];
        
        
        free(array);
        free(colorPlane);
        free(y);
        free(xold);
        free(xold1);
        return image;
    }
    
}
- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    UIGraphicsBeginImageContext(newSize);
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

@end
