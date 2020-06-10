
#import "RNSoundRecorder.h"
#import <AVFoundation/AVFoundation.h>

@implementation RNSoundRecorder {
    AVAudioRecorder* _recorder;
    RCTPromiseResolveBlock _resolveStop;
    RCTPromiseRejectBlock _rejectStop;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

- (NSDictionary *)constantsToExport
{
    return @{
        @"PATH_CACHE": [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject],
        @"PATH_DOCUMENT": [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject],
        @"PATH_LIBRARY": [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject],
    
        @"FORMAT_LinearPCM": @(kAudioFormatLinearPCM),
        @"FORMAT_AC3": @(kAudioFormatAC3),
        @"FORMAT_60958AC3": @(kAudioFormat60958AC3),
        @"FORMAT_AppleIMA4": @(kAudioFormatAppleIMA4),
        @"FORMAT_MPEG4AAC": @(kAudioFormatMPEG4AAC),
        @"FORMAT_MPEG4CELP": @(kAudioFormatMPEG4CELP),
        @"FORMAT_MPEG4HVXC": @(kAudioFormatMPEG4HVXC),
        @"FORMAT_MPEG4TwinVQ": @(kAudioFormatMPEG4TwinVQ),
        @"FORMAT_MACE3": @(kAudioFormatMACE3),
        @"FORMAT_MACE6": @(kAudioFormatMACE6),
        @"FORMAT_ULaw": @(kAudioFormatULaw),
        @"FORMAT_ALaw": @(kAudioFormatALaw),
        @"FORMAT_QDesign": @(kAudioFormatQDesign),
        @"FORMAT_QDesign2": @(kAudioFormatQDesign2),
        @"FORMAT_QUALCOMM": @(kAudioFormatQUALCOMM),
        @"FORMAT_MPEGLayer1": @(kAudioFormatMPEGLayer1),
        @"FORMAT_MPEGLayer2": @(kAudioFormatMPEGLayer2),
        @"FORMAT_MPEGLayer3": @(kAudioFormatMPEGLayer3),
        @"FORMAT_TimeCode": @(kAudioFormatTimeCode),
        @"FORMAT_MIDIStream": @(kAudioFormatMIDIStream),
        @"FORMAT_ParameterValueStream": @(kAudioFormatParameterValueStream),
        @"FORMAT_AppleLossless": @(kAudioFormatAppleLossless),
        @"FORMAT_MPEG4AAC_HE": @(kAudioFormatMPEG4AAC_HE),
        @"FORMAT_MPEG4AAC_LD": @(kAudioFormatMPEG4AAC_LD),
        @"FORMAT_MPEG4AAC_ELD": @(kAudioFormatMPEG4AAC_ELD),
        @"FORMAT_MPEG4AAC_ELD_SBR": @(kAudioFormatMPEG4AAC_ELD_SBR),
        @"FORMAT_MPEG4AAC_HE_V2": @(kAudioFormatMPEG4AAC_HE_V2),
        @"FORMAT_MPEG4AAC_Spatial": @(kAudioFormatMPEG4AAC_Spatial),
        @"FORMAT_AMR": @(kAudioFormatAMR),
        @"FORMAT_Audible": @(kAudioFormatAudible),
        @"FORMAT_iLBC": @(kAudioFormatiLBC),
        @"FORMAT_DVIIntelIMA": @(kAudioFormatDVIIntelIMA),
        @"FORMAT_MicrosoftGSM": @(kAudioFormatMicrosoftGSM),
        @"FORMAT_AES3": @(kAudioFormatAES3),
        @"FORMAT_AMR_WB": @(kAudioFormatAMR_WB),
        @"FORMAT_EnhancedAC3": @(kAudioFormatEnhancedAC3),
        @"FORMAT_MPEG4AAC_ELD_V2": @(kAudioFormatMPEG4AAC_ELD_V2),
    
        @"QUALITY_MAX": @(AVAudioQualityMax),
        @"QUALITY_MIN": @(AVAudioQualityMin),
        @"QUALITY_LOW": @(AVAudioQualityLow),
        @"QUALITY_MEDIUM": @(AVAudioQualityMedium),
        @"QUALITY_HIGH": @(AVAudioQualityHigh)
    
    };
}

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

RCT_EXPORT_METHOD(start:(NSString *)path
                  options:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    if (_recorder && _recorder.isRecording) {
        reject(@"already_recording", @"Already Recording", nil);
        return;
    }

    NSMutableDictionary* settings = [[NSMutableDictionary alloc] init];

    // https://developer.apple.com/documentation/coreaudio/core_audio_data_types/1572096-audio_data_format_identifiers
    NSNumber* format = [options objectForKey:@"format"];
    if (!format) format = @(kAudioFormatMPEG4AAC);
    [settings setObject:format forKey:AVFormatIDKey];

    NSNumber* channels = [options objectForKey:@"channels"];
    if (!channels) channels = @1;
    [settings setObject:channels forKey:AVNumberOfChannelsKey];

    NSNumber* bitRate = [options objectForKey:@"bitRate"];
    if (bitRate) [settings setObject:bitRate forKey:AVEncoderBitRateKey];

    NSNumber* sampleRate = [options objectForKey:@"sampleRate"];
    if (!sampleRate) sampleRate = @16000;
    [settings setObject:sampleRate forKey:AVSampleRateKey];

    NSNumber* quality = [options objectForKey:@"quality"];
    if (!quality) quality = @(AVAudioQualityMax);
    [settings setObject:quality forKey:AVEncoderAudioQualityKey];



    NSError* err = nil;

    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryRecord error:nil];

    NSURL *url = [NSURL fileURLWithPath:path];

    _recorder = [[AVAudioRecorder alloc] initWithURL:url settings:settings error:&err];
    _recorder.delegate = self;

    if (err) {
        _recorder = nil;
        reject(@"init_recorder_error", [[err userInfo] description], err);
        return;
    }

    [_recorder prepareToRecord];
    [_recorder record];
    [session setActive:YES error:nil];

    if (_recorder.isRecording) {
        resolve([NSNull null]);
    } else {
        reject(@"recording_failed", [@"Cannot record audio at path: " stringByAppendingString:[_recorder url].absoluteString], nil);
        _recorder = nil;
    }

}

RCT_EXPORT_METHOD(stop:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    if (!_recorder) {
        reject(@"not_recording", @"Not Recording", nil);
        return;
    }

    _resolveStop = resolve;
    _rejectStop = reject;
    [_recorder stop];
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    NSString* url = [_recorder url].absoluteString;
    url = [url substringFromIndex:NSMaxRange([url rangeOfString:@"://"])];

    AVURLAsset* audioAsset = [AVURLAsset URLAssetWithURL:[_recorder url] options:nil];
    CMTime audioDuration = audioAsset.duration;
    float audioDurationSeconds = CMTimeGetSeconds(audioDuration);
    NSDictionary* response = @{@"duration": @(audioDurationSeconds * 1000), @"path": url};

    dispatch_queue_t myQueue = dispatch_queue_create("com.signal.app", nil);
    dispatch_async(myQueue, ^{
        // deactivate the audio session
        AVAudioSession* session = [AVAudioSession sharedInstance];
        [session setActive:NO error:nil];
        [session setCategory:AVAudioSessionCategoryPlayback error:nil];

        _resolveStop(response);

        // release the recorder promise resolver
        _recorder = nil;
        _resolveStop = nil;
        _rejectStop = nil;
    });
}

RCT_EXPORT_METHOD(pause:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    if (!_recorder || !_recorder.isRecording) {
        reject(@"not_recording", @"Not Recording", nil);
        return;
    }

    [_recorder pause];

    resolve([NSNull null]);
}

RCT_EXPORT_METHOD(resume:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    if (!_recorder) {
        reject(@"not_recording", @"Not yet started recording", nil);
        return;
    }

    if (_recorder.isRecording) {
        reject(@"already_recording", @"Already Recording", nil);
        return;
    }

    [_recorder record];

    resolve([NSNull null]);
}

@end
  
