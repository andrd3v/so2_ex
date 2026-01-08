#import "esp.h"

mach_vm_address_t get_transform_by_object(mach_vm_address_t object, task_t task) {
    return Read<mach_vm_address_t>(object + 0xD8, task);
}

@interface ESP_View ()
@property (nonatomic, strong) NSMutableArray<CALayer *> *layers;
@property (nonatomic, strong) NSMutableArray<CALayer *> *healthLayers;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) CADisplayLink *displayLinkDATA;
@property (nonatomic, strong) NSArray<NSValue *> *boxesData;
@end

@implementation ESP_View

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.layers = [NSMutableArray array];
        self.healthLayers = [NSMutableArray array];
        self.backgroundColor = [UIColor clearColor];

        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateBoxes)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        
        self.displayLinkDATA = [CADisplayLink displayLinkWithTarget:self selector:@selector(update_data)];
        [self.displayLinkDATA addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.superview) {
        self.frame = self.superview.bounds;
    }
    [self updateBoxes];
}

- (void)setBoxes:(NSArray<NSValue *> *)boxes
{
    _boxesData = [boxes copy];
    [self updateBoxes];
}

- (void)updateBoxes {
    if (!self.window) return;
    NSUInteger count = self.boxesData.count;
    
    if (count == 0)
    {
        for (CALayer *layer in self.layers)
        {
            [layer removeFromSuperlayer];
        }
        for (CALayer *healthLayer in self.healthLayers)
        {
            [healthLayer removeFromSuperlayer];
        }
        [self.layers removeAllObjects];
        [self.healthLayers removeAllObjects];
        return;
    }
    
    while (self.layers.count < count)
    {
        CALayer *layer = [CALayer layer];
        layer.borderColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:1.0].CGColor;
        layer.borderWidth = 1.0;
        layer.cornerRadius = 2.0;
        [self.layer addSublayer:layer];
        [self.layers addObject:layer];
        
        CALayer *healthLayer = [CALayer layer];
        healthLayer.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0].CGColor;
        healthLayer.cornerRadius = 1.0;
        [self.layer addSublayer:healthLayer];
        [self.healthLayers addObject:healthLayer];
    }
    
    for (NSUInteger i = 0; i < self.layers.count; i++)
    {
        CALayer *layer = self.layers[i];
        CALayer *healthLayer = self.healthLayers[i];

        if (i < count)
        {
            ESPBox box;
            [self.boxesData[i] getValue:&box];
            layer.hidden = NO;
            healthLayer.hidden = NO;
            
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
   
            layer.frame = CGRectMake(box.pos.x, box.pos.y, box.width, box.height);
  
            float healthLineWidth = 2.0f;
            float healthLineX = box.pos.x - healthLineWidth - 2.0f;
            float healthLineY = box.pos.y;
            float healthLineHeight = box.height;
            
            healthLayer.frame = CGRectMake(healthLineX, healthLineY, healthLineWidth, healthLineHeight);
            
            [CATransaction commit];

        } else {
            layer.hidden = YES;
            healthLayer.hidden = YES;
        }
    }
}

- (void)dealloc {
    [self.displayLink invalidate];
    [self.displayLinkDATA invalidate];
    self.displayLink = nil;
    self.displayLinkDATA = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)update_data
{
    pid_t so2_pid = get_pid_by_name("Standoff2");
    if (so2_pid == 0) {
        return;
    }

    task_t so2_task = get_task_by_pid(so2_pid);
    if (so2_task == 0) {
        return;
    }

    mach_vm_address_t unity_base_addr = get_image_base_address(so2_task, "UnityFramework");
    if (unity_base_addr == 0) {
        return;
    }

    mach_vm_address_t typinfo = Read<mach_vm_address_t>(unity_base_addr + 0x840b670, so2_task);
    if (typinfo == 0) {
        return;
    }

    mach_vm_address_t lazysingleton = Read<mach_vm_address_t>(typinfo + 0x58, so2_task);
    if (lazysingleton == 0) {
        return;
    }

    mach_vm_address_t statik = Read<mach_vm_address_t>(lazysingleton + 0xB8, so2_task);
    if (statik == 0) {
        return;
    }

    mach_vm_address_t inst = Read<mach_vm_address_t>(statik + 0x0, so2_task);
    if (inst == 0) {
        return;
    }

    mach_vm_address_t local_addr = Read<mach_vm_address_t>(inst + 0x70, so2_task);
    if (local_addr == 0) {
        return;
    }

    uint8_t localTeam = Read<uint8_t>(local_addr + 0x59, so2_task);

    using players_dict = Dictionary<int, mach_vm_address_t>;
    mach_vm_address_t players_dict_obj_addr = Read<mach_vm_address_t>(inst + 0x28, so2_task);

    mach_vm_address_t local_player = Read<mach_vm_address_t>(inst + 0x70, so2_task);
    if (!local_player) {
        return;
    }

    mach_vm_address_t camera_class = Read<mach_vm_address_t>(local_player + 0xC0, so2_task);
    mach_vm_address_t camera = Read<mach_vm_address_t>(camera_class + 0x20, so2_task);
    if (!camera) return;

    if (players_dict_obj_addr)
    {
        players_dict dict(so2_task, (uintptr_t)players_dict_obj_addr);
        int count = dict.get_Count();
        
        if (count > 0)
        {
            auto keys = dict.get_Keys();
            auto values = dict.get_Values();

            NSMutableArray<NSValue *> *boxesMutable = [NSMutableArray array];
            CGSize screenSize = self.bounds.size;

            for (int i = 0; i < count; ++i)
            {
                mach_vm_address_t player_addr = values[i];
                uint8_t playerTeam = Read<uint8_t>(player_addr + 0x59, so2_task);
                if (playerTeam == localTeam) {
                    continue;
                }
                
                mach_vm_address_t player_transform = Read<mach_vm_address_t>(player_addr + 0xD8, so2_task);
                Vector3 vec3_pos_trnsfrm = get_position_by_transform(player_transform, so2_task);

                if (vec3_pos_trnsfrm.x == 0.0f && vec3_pos_trnsfrm.y == 0.0f && vec3_pos_trnsfrm.z == 0.0f) {
                    continue;
                }

                const float totalPlayerHeight = 2.5f;

                const float halfHeight = totalPlayerHeight * 0.5f;

                Vector3 head_world = vec3_pos_trnsfrm; head_world.y += halfHeight;

                Vector3 top_w2s = WorldToScreen(head_world, camera, screenSize.width, screenSize.height, so2_task);

                Vector3 bottom_w2s = WorldToScreen(vec3_pos_trnsfrm, camera, screenSize.width, screenSize.height, so2_task);

                if ((bottom_w2s.x==0&&bottom_w2s.y==0&&bottom_w2s.z==0) ||

                    (top_w2s.x==0&&top_w2s.y==0&&top_w2s.z==0)) {
                    continue;
                }
                
                float height = fabsf(top_w2s.y - bottom_w2s.y);

                if (height <= 0.0f) {
                    continue;
                }

                float width = fabsf(height / 2.0f);

                ESPBox box;
                box.pos = bottom_w2s;
                box.pos.x = bottom_w2s.x - (width / 2.0f);
                box.pos.y = bottom_w2s.y - height - 4.0f;
                box.pos.z = 0.0f;
                box.width = width;
                box.height = height;

                NSValue *val = [NSValue valueWithBytes:&box objCType:@encode(ESPBox)];
                [boxesMutable addObject:val];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self setBoxes:boxesMutable];
            });
        }
    }
}

@end