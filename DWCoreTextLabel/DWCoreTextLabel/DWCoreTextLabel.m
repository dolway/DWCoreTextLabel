//
//  DWCoreTextLabel.m
//  DWCoreTextLabel
//
//  Created by Wicky on 16/12/4.
//  Copyright © 2016年 Wicky. All rights reserved.
//

#import "DWCoreTextLabel.h"
#import <CoreText/CoreText.h>
static DWTextImageDrawMode DWTextImageDrawModeInsert = 2;
@interface DWCoreTextLabel ()

@property (nonatomic ,strong) NSMutableArray * exclusionP;

@property (nonatomic ,strong) NSMutableArray * imageArr;

@property (nonatomic ,strong) NSMutableArray * imageExclusion;

@property (nonatomic ,strong) NSMutableArray * arrLocationImgHasAdd;

@end

@implementation DWCoreTextLabel
@synthesize font = _font;
@synthesize textColor = _textColor;
@synthesize exclusionPaths = _exclusionPaths;
@synthesize lineSpacing = _lineSpacing;

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _lineSpacing = - 65536;
        _lineBreakMode = NSLineBreakByCharWrapping;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    
    ///坐标系处理
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGContextTranslateCTM(context, 0, self.bounds.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    ///计算绘制尺寸限制
    CGFloat limitWidth = (self.bounds.size.width - self.textInsets.left - self.textInsets.right) > 0 ? (self.bounds.size.width - self.textInsets.left - self.textInsets.right) : 0;
    CGFloat limitHeight = (self.bounds.size.height - self.textInsets.top - self.textInsets.bottom) > 0 ? (self.bounds.size.height - self.textInsets.top - self.textInsets.bottom) : 0;
    
    ///获取要绘制的文本
    NSMutableAttributedString * mAStr = [self getMAStrWithLimitWidth:limitWidth];
    
    ///处理插入图片
    NSMutableArray * arrInsert = [NSMutableArray array];
    [self.imageArr enumerateObjectsUsingBlock:^(NSDictionary * dic, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([dic[@"drawMode"] integerValue] == DWTextImageDrawModeInsert) {
            [arrInsert addObject:dic];
        }
    }];
    
    ///富文本插入图片占位符
    [self handleStr:mAStr withInsertImageArr:arrInsert];
    
    ///添加工厂
    CTFramesetterRef frameSetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)mAStr);
    
    ///生成绘制尺寸
    CGSize suggestSize = [self getSuggestSizeWithFrameSetter:frameSetter limitWidth:limitWidth strToDraw:mAStr];
    
    CGRect frame = CGRectMake(self.textInsets.left, self.textInsets.bottom, limitWidth, limitHeight);
    
    ///处理图片排除区域
    [self handleImageExclusionWithFrame:frame];
    
    ///处理对其方式方式
    [self handleAlignmentWithFrame:frame suggestSize:suggestSize limitWidth:limitWidth];
    
    ///创建绘制区域
    UIBezierPath * path = [UIBezierPath bezierPathWithRect:frame];
    
    ///排除区域处理
    if (self.exclusionPaths.count) {
        [self handleDrawPath:path frame:frame exclusionArray:self.exclusionP];
    }
    
    ///图片环绕区域处理
    if (self.imageExclusion.count) {
        [self handleDrawPath:path frame:frame exclusionArray:self.imageExclusion];
    }
    
    ///获取全部绘制区域
    CTFrameRef _frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, mAStr.length), path.CGPath, NULL);
    
    ///获取范围内可显示范围
    CFRange range = CTFrameGetVisibleStringRange(_frame);
    
    ///获取可显示绘制区域
    if (range.length < mAStr.length) {
        _frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, range.length), path.CGPath, NULL);
    }
    
    ///计算插入图片的frame
    [self handleInsertImageFrameWithArr:arrInsert frame:_frame];
    
    ///绘制图片
    [self.imageArr enumerateObjectsUsingBlock:^(NSDictionary * dic, NSUInteger idx, BOOL * _Nonnull stop) {
        UIImage * image = dic[@"image"];
        CGRect frame = [self convertRect:[dic[@"frame"] CGRectValue]];
        CGContextDrawImage(context, frame, image.CGImage);
    }];
    
    ///绘制上下文
    CTFrameDraw(_frame, context);
    
    ///内存管理
    CFRelease(_frame);
    CFRelease(frameSetter);
}

#pragma mark ---插入图片相关---
///在字符串指定位置插入图片
-(void)insertImage:(UIImage *)image size:(CGSize)size atLocation:(NSUInteger)location descent:(CGFloat)descent
{
    NSMutableDictionary * dic = [NSMutableDictionary dictionaryWithDictionary:@{@"image":image,@"size":[NSValue valueWithCGSize:size],@"location":@(location),@"descent":@(descent),@"drawMode":@(DWTextImageDrawModeInsert)}];
    [self.imageArr addObject:dic];
    [self handleAutoRedraw];
}

#pragma mark ---绘制图片---
///以指定模式绘制图片
-(void)drawImage:(UIImage *)image atFrame:(CGRect)frame drawMode:(DWTextImageDrawMode)mode
{
    switch (mode) {
        case DWTextImageDrawModeCover:
        {
           
        }
            break;
        default:
        {
            
        }
            break;
    }
    NSMutableDictionary * dic = [NSMutableDictionary dictionaryWithDictionary:@{@"image":image,@"frame":[NSValue valueWithCGRect:frame],@"drawMode":@(mode)}];
    [self.imageArr addObject:dic];
    [self handleAutoRedraw];
}


#pragma mark ---tool method---

#pragma mark ---插入图片相关---
///将所有插入图片插入字符串
-(void)handleStr:(NSMutableAttributedString *)str withInsertImageArr:(NSMutableArray *)arr
{
    [arr enumerateObjectsUsingBlock:^(NSMutableDictionary * dic, NSUInteger idx, BOOL * _Nonnull stop) {
        [self insertPicWithDictionary:dic toStr:str];
    }];
}

///将所有插入图片的字典中的frame补全
-(void)handleInsertImageFrameWithArr:(NSMutableArray *)arr
                               frame:(CTFrameRef)frame
{
    [arr enumerateObjectsUsingBlock:^(NSMutableDictionary * dic, NSUInteger idx, BOOL * _Nonnull stop) {
        UIImage * image = dic[@"image"];
        CGRect rect = [self getRectWithImage:image frame:frame];
        if (!CGRectEqualToRect(rect, CGRectNull)) {
            rect = [self convertRect:rect];
            dic[@"frame"] = [NSValue valueWithCGRect:rect];
        }
    }];
}

///将图片设置代理后插入富文本
-(void)insertPicWithDictionary:(NSMutableDictionary *)dic
                         toStr:(NSMutableAttributedString *)str
{
    NSInteger location = [dic[@"location"] integerValue];
    CTRunDelegateCallbacks callBacks;
    memset(&callBacks, 0, sizeof(CTRunDelegateCallbacks));
    callBacks.version = kCTRunDelegateVersion1;
    callBacks.getAscent = ascentCallBacks;
    callBacks.getDescent = descentCallBacks;
    callBacks.getWidth = widthCallBacks;
    CTRunDelegateRef delegate = CTRunDelegateCreate(& callBacks, (__bridge void *)dic);
    unichar placeHolder = 0xFFFC;
    NSString * placeHolderStr = [NSString stringWithCharacters:&placeHolder length:1];
    NSMutableAttributedString * placeHolderAttrStr = [[NSMutableAttributedString alloc] initWithString:placeHolderStr];
    CFAttributedStringSetAttribute((CFMutableAttributedStringRef)placeHolderAttrStr, CFRangeMake(0, 1), kCTRunDelegateAttributeName, delegate);
    CFRelease(delegate);
    NSInteger offset = [self addToArrImgDicAndSortWithLocation:location];
    [str insertAttributedString:placeHolderAttrStr atIndex:location + offset];
}

///插入图片偏移量
-(NSInteger)addToArrImgDicAndSortWithLocation:(NSInteger)location
{
    NSNumber * loc = [NSNumber numberWithInteger:location];
    if (self.arrLocationImgHasAdd.count == 0) {//如果数组是空的，直接添加位置，并返回0
        [self.arrLocationImgHasAdd addObject:loc];
        return 0;
    }
    [self.arrLocationImgHasAdd addObject:loc];//否则先插入，再排序
    [self.arrLocationImgHasAdd sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {//升序排序方法
        if ([obj1 integerValue] > [obj2 integerValue]) {
            return (NSComparisonResult)NSOrderedDescending;
        }
        
        if ([obj1 integerValue] < [obj2 integerValue]) {
            return (NSComparisonResult)NSOrderedAscending;
        }
        return (NSComparisonResult)NSOrderedSame;
    }];
    return [self.arrLocationImgHasAdd indexOfObject:loc];//返回本次插入图片的偏移量
}

#pragma mark ---文本相关---
///获取当前需要绘制的文本
-(NSMutableAttributedString *)getMAStrWithLimitWidth:(CGFloat)limitWidth
{
    NSMutableAttributedString * mAStr = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
    NSUInteger length = self.attributedText?self.attributedText.length:self.text.length;
    NSMutableParagraphStyle * paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    NSRange totalRange = NSMakeRange(0, length);
    if (!self.attributedText) {
        
        [paragraphStyle setLineBreakMode:self.lineBreakMode];
        [paragraphStyle setLineSpacing:self.lineSpacing];//行间距
        paragraphStyle.alignment = (self.exclusionPaths.count == 0)?self.textAlignment:NSTextAlignmentLeft;
        NSMutableAttributedString * attributeStr = [[NSMutableAttributedString alloc] initWithString:self.text];
        [attributeStr addAttribute:NSFontAttributeName value:self.font range:totalRange];
        [attributeStr addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:totalRange];
        [attributeStr addAttribute:NSForegroundColorAttributeName value:self.textColor range:totalRange];
        mAStr = attributeStr;
    }
    else
    {
        [paragraphStyle setLineBreakMode:self.lineBreakMode];
        paragraphStyle.alignment = (self.exclusionPaths.count == 0)?self.textAlignment:NSTextAlignmentLeft;
        [mAStr addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:totalRange];
    }
    
    CTFramesetterRef frameSetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)mAStr);
    CFRange range = [self getLastLineRangeWithFrameSetter:frameSetter limitWidth:limitWidth];
    NSMutableParagraphStyle * newPara = [paragraphStyle mutableCopy];
    newPara.lineBreakMode = NSLineBreakByTruncatingTail;
    [mAStr addAttribute:NSParagraphStyleAttributeName value:newPara range:NSMakeRange(range.location, range.length)];
    return mAStr;
}

///处理图片环绕数组，绘制前调用
-(void)handleImageExclusionWithFrame:(CGRect)frame
{
    [self.imageExclusion removeAllObjects];
    [self.imageArr enumerateObjectsUsingBlock:^(NSDictionary * dic, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([dic[@"drawMode"] integerValue] == DWTextImageDrawModeSurround) {
            CGRect imgFrame = [dic[@"frame"] CGRectValue];
            CGRect newFrame = CGRectIntersection(frame,imgFrame);
            [self.imageExclusion addObject:[UIBezierPath bezierPathWithRect:newFrame]];
        }
    }];
}

///处理对齐方式
-(void)handleAlignmentWithFrame:(CGRect)frame
                    suggestSize:(CGSize)suggestSize
                     limitWidth:(CGFloat)limitWidth
{
    if ((self.exclusionPaths.count + self.imageExclusion.count) == 0) {///若无排除区域按对齐方式处理
        if (frame.size.height > suggestSize.height) {///垂直对齐方式处理
            frame.size = suggestSize;
            CGPoint origin = frame.origin;
            if (self.textVerticalAlignment == DWTextVerticalAlignmentCenter) {
                origin.y = self.bounds.size.height / 2.0 - suggestSize.height / 2.0;
            }
            else if (self.textVerticalAlignment == DWTextVerticalAlignmentTop)
            {
                origin.y = self.bounds.size.height - suggestSize.height - self.textInsets.top;
            }
            frame.origin = origin;
        }
        
        if (frame.size.width < limitWidth) {///水平对齐方式处理
            CGPoint origin = frame.origin;
            if (self.textAlignment == NSTextAlignmentCenter) {
                origin.x = self.bounds.size.width / 2.0 - frame.size.width / 2.0;
            }
            else if (self.textAlignment == NSTextAlignmentRight)
            {
                origin.x = self.bounds.size.width - frame.size.width - self.textInsets.right;
            }
            frame.origin = origin;
        }
    }
}

///处理绘制Path，绘制前调用
-(void)handleDrawPath:(UIBezierPath *)path frame:(CGRect)frame exclusionArray:(NSMutableArray *)array
{
    [array enumerateObjectsUsingBlock:^(UIBezierPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (CGRectContainsRect(path.bounds, obj.bounds)) {
            [self dw_MirrorPath:obj inBounds:frame];
            [path appendPath:obj];
        }
    }];
}

#pragma mark ---转换类方法---
///获取镜像path
-(void)dw_MirrorPath:(UIBezierPath *)path inBounds:(CGRect)bounds
{
    [path applyTransform:CGAffineTransformMakeScale(1, -1)];
    [path applyTransform:CGAffineTransformMakeTranslation(0, 2 * bounds.origin.y + bounds.size.height)];
}

///获取镜像frame
-(CGRect)convertRect:(CGRect)rect
{
    return CGRectMake(rect.origin.x, self.bounds.size.height - rect.origin.y - rect.size.height, rect.size.width, rect.size.height);
}

#pragma mark ---获取相关数据方法---
///获取绘制尺寸
-(CGSize)getSuggestSizeWithFrameSetter:(CTFramesetterRef)frameSetter
                            limitWidth:(CGFloat)limitWidth
                             strToDraw:(NSMutableAttributedString *)str
{
    CGSize restrictSize = CGSizeMake(limitWidth, MAXFLOAT);
    if (self.numberOflines == 1) {
        restrictSize = CGSizeMake(MAXFLOAT, MAXFLOAT);
    }
    CFRange rangeToDraw = [self getRangeToDrawWithFrameSetter:frameSetter limitWidth:limitWidth strToDraw:str];
    CGSize suggestSize = CTFramesetterSuggestFrameSizeWithConstraints(frameSetter, rangeToDraw, nil, restrictSize, nil);
    return CGSizeMake(MIN(suggestSize.width, limitWidth), suggestSize.height);
}

///获取绘制范围
-(CFRange)getRangeToDrawWithFrameSetter:(CTFramesetterRef)frameSetter
                             limitWidth:(CGFloat)limitWidth
                              strToDraw:(NSMutableAttributedString *)str
{
    CFRange rangeToDraw = CFRangeMake(0, str.length);
    CFRange range = [self getLastLineRangeWithFrameSetter:frameSetter limitWidth:limitWidth];
    if (range.length > 0) {
        rangeToDraw = CFRangeMake(0, range.location + range.length);
    }
    return rangeToDraw;
}

///获取最后一行绘制范围
-(CFRange)getLastLineRangeWithFrameSetter:(CTFramesetterRef)frameSetter
                               limitWidth:(CGFloat)limitWidth
{
    CFRange range = CFRangeMake(0, 0);
    if (self.numberOflines > 0) {
        CGMutablePathRef path = CGPathCreateMutable();
        CGPathAddRect(path, NULL, CGRectMake(0.0f, 0.0f, limitWidth, MAXFLOAT));
        CTFrameRef frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, 0), path, NULL);
        CFArrayRef lines = CTFrameGetLines(frame);
        if (CFArrayGetCount(lines) > 0) {
            NSUInteger lineNum = MIN(self.numberOflines, CFArrayGetCount(lines));
            CTLineRef line = CFArrayGetValueAtIndex(lines, lineNum - 1);
            range = CTLineGetStringRange(line);
        }
        CFRelease(path);
        CFRelease(frame);
    }
    return range;
}

///获取对应图片的绘制frame
-(CGRect)getRectWithImage:(UIImage *)image
                    frame:(CTFrameRef)frame
{
    NSArray * arrLines = (NSArray *)CTFrameGetLines(frame);
    NSInteger count = [arrLines count];
    CGPoint points[count];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), points);
    for (int i = 0; i < count; i ++) {
        CTLineRef line = (__bridge CTLineRef)arrLines[i];
        NSArray * arrGlyphRun = (NSArray *)CTLineGetGlyphRuns(line);
        for (int j = 0; j < arrGlyphRun.count; j ++) {
            CTRunRef run = (__bridge CTRunRef)arrGlyphRun[j];
            NSDictionary * attributes = (NSDictionary *)CTRunGetAttributes(run);
            CTRunDelegateRef delegate = (__bridge CTRunDelegateRef)[attributes valueForKey:(id)kCTRunDelegateAttributeName];
            if (delegate == nil) {
                continue;
            }
            NSDictionary * dic = CTRunDelegateGetRefCon(delegate);
            if (![dic isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            if (![dic[@"image"] isEqual:image]) {
                continue;
            }
            CGPoint point = points[i];
            CGFloat ascent;
            CGFloat descent;
            CGRect boundsRun = CGRectZero;
            boundsRun.size.width = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, NULL);
            boundsRun.size.height = ascent + descent;
            CGFloat xOffset = CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, NULL);
            boundsRun.origin.x = point.x + xOffset;
            boundsRun.origin.y = point.y - descent;
            CGPathRef path = CTFrameGetPath(frame);
            CGRect colRect = CGPathGetBoundingBox(path);
            CGRect deleteBounds = CGRectOffset(boundsRun, colRect.origin.x, colRect.origin.y);
            return deleteBounds;
        }
    }
    return CGRectNull;
}

///自动重绘
-(void)handleAutoRedraw
{
    if (self.autoRedraw) {
        [self setNeedsDisplay];
    }
}

#pragma mark ---CTRUN代理---
static CGFloat ascentCallBacks(void * ref)
{
    NSDictionary * dic = (__bridge NSDictionary *)ref;
    CGSize size = [dic[@"size"] CGSizeValue];
    CGFloat descent = [dic[@"descent"] floatValue];
    return size.height - descent;
}

static CGFloat descentCallBacks(void * ref)
{
    NSDictionary * dic = (__bridge NSDictionary *)ref;
    CGFloat descent = [dic[@"descent"] floatValue];
    return descent;
}

static CGFloat widthCallBacks(void * ref)
{
    NSDictionary * dic = (__bridge NSDictionary *)ref;
    CGSize size = [dic[@"size"] CGSizeValue];
    return size.width;
}

#pragma mark ---method override---
//-(void)sizeToFit
//{
//    CGRect frame = self.frame;
//    frame.size = [self sizeThatFits:CGSizeMake(self.bounds.size.width, 0)];
//    self.frame = frame;
//}
//
//-(CGSize)sizeThatFits:(CGSize)size
//{
//    CGFloat limitWidth = (size.width - self.textInsets.left - self.textInsets.right) > 0 ? (self.bounds.size.width - self.textInsets.left - self.textInsets.right) : 0;
//    NSMutableAttributedString * mAStr = [self getMAStr];
//    CTFramesetterRef frameSetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)mAStr);//一个frame的工厂，负责生成frame
//    
//    CGSize suggestSize = [self getSuggestSizeWithFrameSetter:frameSetter limitWidth:limitWidth];
//    
//    return CGSizeMake(suggestSize.width + self.textInsets.left + self.textInsets.right, suggestSize.height + self.textInsets.top + self.textInsets.bottom);
//}
#pragma mark ---setter、getter---
-(void)setText:(NSString *)text
{
    _text = text;
    [self handleAutoRedraw];
}

-(void)setTextAlignment:(NSTextAlignment)textAlignment
{
    if (self.exclusionPaths.count == 0) {
        _textAlignment = textAlignment;
        [self handleAutoRedraw];
    }
}

-(void)setTextVerticalAlignment:(DWTextVerticalAlignment)textVerticalAlignment
{
    if (self.exclusionPaths.count == 0) {
        _textVerticalAlignment = textVerticalAlignment;
        [self handleAutoRedraw];
    }
}

-(UIFont *)font
{
    if (!_font) {
        _font = [UIFont systemFontOfSize:17];
    }
    return _font;
}

-(void)setFont:(UIFont *)font
{
    _font = font;
    [self handleAutoRedraw];
}

-(void)setTextInsets:(UIEdgeInsets)textInsets
{
    _textInsets = textInsets;
    [self handleAutoRedraw];
}

-(void)setAttributedText:(NSAttributedString *)attributedText
{
    _attributedText = attributedText;
    [self handleAutoRedraw];
}

-(void)setTextColor:(UIColor *)textColor
{
    _textColor = textColor;
    [self handleAutoRedraw];
}

-(UIColor *)textColor
{
    if (!_textColor) {
        _textColor = [UIColor blackColor];
    }
    return _textColor;
}

-(void)setLineSpacing:(CGFloat)lineSpacing
{
    _lineSpacing = lineSpacing;
    [self handleAutoRedraw];
}

-(CGFloat)lineSpacing
{
    if (_lineSpacing == -65536) {
        return 5.5;
    }
    return _lineSpacing;
}

-(NSMutableArray<UIBezierPath *> *)exclusionPaths
{
    if (!_exclusionPaths) {
        _exclusionPaths = [NSMutableArray array];
    }
    return _exclusionPaths;
}

-(void)setExclusionPaths:(NSMutableArray<UIBezierPath *> *)exclusionPaths
{
    _exclusionPaths = exclusionPaths;
    [self handleAutoRedraw];
}

-(NSMutableArray *)exclusionP
{
    return [self.exclusionPaths copy];
}

-(NSMutableArray *)imageArr
{
    if (!_imageArr) {
        _imageArr = [NSMutableArray array];
    }
    return _imageArr;
}

-(NSMutableArray *)imageExclusion
{
    if (!_imageExclusion) {
        _imageExclusion = [NSMutableArray array];
    }
    return _imageExclusion;
}

-(NSMutableArray *)arrLocationImgHasAdd
{
    if (!_arrLocationImgHasAdd) {
        _arrLocationImgHasAdd = [NSMutableArray array];
    }
    return _arrLocationImgHasAdd;
}
@end