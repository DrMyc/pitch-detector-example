/*
 Copyright (c) Kevin P Murphy June 2012
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "FreqViewController.h"

@interface FreqViewController ()

@property (nonatomic) NSArray *pitchNames;
@property (nonatomic) double lowAFreq;
@property (nonatomic) double currentFreq;
@property (nonatomic) double lowPassResults;

@end

#define LOW_PASS_THRESHOLD 0.25

@implementation FreqViewController
- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self  = [super initWithNibName:nil bundle:nil];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //#### Jesse {
    self.pitchNames = @[@"A", @"A#", @"B", @"C", @"C#", @"D", @"D#", @"E", @"F", @"F#", @"G", @"G#"];
    self.lowAFreq = log2(27.5);
    
    //##### } Jesse
    
    audioManager = [AudioController sharedAudioManager];
    audioManager.delegate = self;
    autoCorrelator = [[PitchDetector alloc] initWithSampleRate:audioManager.audioFormat.mSampleRate lowBoundFreq:30 hiBoundFreq:4500 andDelegate:self];
    
    medianPitchFollow = [[NSMutableArray alloc] initWithCapacity:22];
    
    freqLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 80)];
    freqLabel.center = CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2);
    freqLabel.backgroundColor = [UIColor clearColor];
    freqLabel.textAlignment = UITextAlignmentCenter;
    
    [self.view addSubview:freqLabel];
    
}

- (void)viewWillAppear:(BOOL)animated {
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void) updatedPitch:(float)frequency {
    
    double value = frequency;
    
    //############ DATA SMOOTHING ###############
    //###     The following code averages previous values  ##
    //###  received by the pitch follower by using a             ##
    //###  median filter. Provides sub cent precision!          ##
    //#############################################
    
    NSNumber *nsnum = [NSNumber numberWithDouble:value];
    [medianPitchFollow insertObject:nsnum atIndex:0];
    
    if(medianPitchFollow.count>22) {
        [medianPitchFollow removeObjectAtIndex:medianPitchFollow.count-1];
    }
    double median = 0;
    
    if(medianPitchFollow.count>=2) {
        NSSortDescriptor *highestToLowest = [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:NO];
        NSMutableArray *tempSort = [NSMutableArray arrayWithArray:medianPitchFollow];
        [tempSort sortUsingDescriptors:[NSArray arrayWithObject:highestToLowest]];
        
        if(tempSort.count%2==0) {
            double first = 0, second = 0;
            first = [[tempSort objectAtIndex:tempSort.count/2-1] doubleValue];
            second = [[tempSort objectAtIndex:tempSort.count/2] doubleValue];
            median = (first+second)/2;
            value = median;
        } else {
            median = [[tempSort objectAtIndex:tempSort.count/2] doubleValue];
            value = median;
        }
        
        [tempSort removeAllObjects];
        tempSort = nil;
    }
    
    self.currentFreq = value;
    [self updateLabel];
}

- (void) receivedAudioSamples:(SInt16 *)samples length:(int)len {
    [autoCorrelator addSamples:samples inNumberFrames:len];
}


//#### Jesse {

- (void)updateLabel
{
    double logFreq = log2(self.currentFreq);
    double octavesAboveLowA = logFreq - self.lowAFreq;
    NSString *pitchName = [self pitchNameForFrequency: octavesAboveLowA];
    freqLabel.text = [NSString stringWithFormat:@"%@ | %3.1f Hz", pitchName, self.currentFreq];
    double mod = octavesAboveLowA - floorf(octavesAboveLowA);
    CGPoint labelCenter = freqLabel.center;
    CGFloat superHeight = freqLabel.superview.bounds.size.height;
    labelCenter.y = superHeight - superHeight * mod;
    freqLabel.center = labelCenter;
    
    freqLabel.hidden = (autoCorrelator.isAboveThresholdVolume) ? NO : YES;
}

- (NSString *) pitchNameForFrequency: (float)octavesAboveLowA
    {
    NSString *pitchName;
    NSString *octaveString = [NSString stringWithFormat:@"%i", (int)octavesAboveLowA];
    double mod = octavesAboveLowA - floorf(octavesAboveLowA);
    int pitchIdx = roundf(mod * 12.0);
    pitchIdx = pitchIdx % 12;
    NSString *pitchLetter = self.pitchNames[pitchIdx];
    pitchName = [pitchLetter stringByAppendingString:octaveString];
    return pitchName;
}


- (BOOL) prefersStatusBarHidden {
    return YES;
}

//#### } Jesse


@end
