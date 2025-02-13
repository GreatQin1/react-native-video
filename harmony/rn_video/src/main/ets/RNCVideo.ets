/**
 * MIT License
 *
 * Copyright (C) 2023 Huawei Device Co., Ltd.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import {
  Descriptor,
  RNOHContext,
  ViewBaseProps,
  RNViewBase,
} from '@rnoh/react-native-openharmony'

import { PlayPlayer } from './view/PlayPlayer';
import { VideoController } from './controller/VideoController';
import { PlayConstants } from './common/constants/PlayConstants';

import { CommonConstants } from './common/constants/CommonConstants';
import Logger from './common/util/Logger';
import { display } from '@kit.ArkUI';

class RNCVideoSrcRequestHeaders  {
  key:string = ''
  value:string =''
}

class RNCVideoSrc  {
  uri:string = ''
  isNetwork:boolean = true
  isAsset:boolean = false
  shouldCache:boolean = false
  type:string = ''
  mainVer: number = 0
  patchVer: number = 0
  requestHeaders?: RNCVideoSrcRequestHeaders[]
}

export interface RNCVideoProps extends ViewBaseProps {
  src: RNCVideoSrc
  // srcType: string
  paused: boolean
  resizeMode: string
  muted: boolean
  repeat: boolean
  volume: number
  disableFocus: boolean
  preventsDisplaySleepDuringVideoPlayback: boolean
}

export const RNC_VIDEO_TYPE: string = "RNCVideo"

export type VideoViewDescriptor = Descriptor<'RNCVideo', RNCVideoProps>
// export type VideoViewDescriptor = Descriptor<RNC_VIDEO_TYPE, RNCVideoProps>

export interface IRNCVideo {
  videoMargin: string
  onVideoLoadStart: (cUri: string) => void
  onReadyForDisplay: () => void
  onVideoProgress: (currentTime: number, _playableDuration:number, _seekableDuration:number) => void
  onVideoLoad: (startSecond:number,length:number,widthIn:number,heightIn:number,orientationIn:string) => void
  onVideoBuffer: (isBufferingIn: boolean) => void
  onVideoPlaybackStalled: () => void
  onVideoPlaybackResume: () => void
  onVideoEnd: () => void
  onVideoError: (err:string) => void
}

@Component
export struct RNCVideo {
  ctx!: RNOHContext
  tag: number = -1
  @State descriptor: VideoViewDescriptor = {} as VideoViewDescriptor
  private unregisterDescriptorChangesListener?: () => void = undefined
  private cleanupCommandCallback?: () => void = undefined

  @State videoMargin: string = PlayConstants.PLAY_PAGE.MARGIN_ZERO;

  private playVideoModel: VideoController = new VideoController();

  srcParam: string = '';/*外部传入参数src*/
  @Provide('srcVar') src: string = '';/*最终avplayer认识的 字符串*/
  @Provide index: number = 0;
  @Provide type: number = CommonConstants.TYPE_LOCAL ;//TODO:luoxf 修改td
  @Provide('mutedVar') muted: boolean = false;
  @Provide('repeatVar') repeat: boolean = false
  @Provide('pausedVar') paused: boolean = false;
  @Provide('resizeModeVar') resizeMode: string = "none";/* */
  @Provide('volumeVar') volume: number = PlayConstants.PLAY_PAGE.VOLUME;
  @Provide('disableFocusVar') disableFocus: boolean = false; /* RN侧默认是独占模式传递FALSE过来，鸿蒙默认未共享模式*/
  @Provide('preventsDisplaySleepDuringVideoPlaybackVar') preventsDisplaySleepDuringVideoPlayback: boolean = true; /* 默认true*/

  private isResume: boolean = false
  @State
  viewWidth:number = 0
  @State
  viewHeight:number = 0
  @Provide
  videoHeight: number|string = CommonConstants.FULL_PERCENT;
  @Provide
  videoWidth: number|string = CommonConstants.FULL_PERCENT;
  @Provide
  changedViewWidth:number = 0
  @Provide
  changedviewHeight:number = 0

  aboutToAppear() {
    Logger.debug(`RNOH in RNCVideo aboutToAppear 修改后 !}`);
    this.descriptor = this.ctx.descriptorRegistry.getDescriptor<VideoViewDescriptor>(this.tag)
    Logger.debug(`RNOH in RNCVideo descriptor props, ${JSON.stringify(this.descriptor.props)}`);
    Logger.debug(`RNOH in RNCVideo descriptor layoutMetrics, ${JSON.stringify(this.descriptor.layoutMetrics)}`);
    this.unregisterDescriptorChangesListener = this.ctx.descriptorRegistry.subscribeToDescriptorChanges(this.tag,
      (newDescriptor) => {
        this.descriptor = (newDescriptor as VideoViewDescriptor)
        /*------ 当RN侧属性props有更改 -------*/
        Logger.debug(`RNOH in RNCVideo descriptor change, `);
        Logger.debug(`RNOH in RNCVideo newDescriptor props, ${JSON.stringify(this.descriptor.props)}`);
        this.updatePropFromDesc()
        this.preparePlayer();
        this.videoWidth = this.viewWidth

        if(display.getDefaultDisplaySync().orientation == 0 || display.getDefaultDisplaySync().orientation == 2){
          this.videoWidth = CommonConstants.FULL_PERCENT;
       //   this.videoHeight = CommonConstants.FULL_PERCENT;
        }


      }
    )
    this.playVideoModel.initPlayPageThis(this as IRNCVideo);
    /*------ 初始化 -------*/
    this.updatePropFromDesc();
    this.preparePlayer();

    this.registerCommandCallback()

  }

  async aboutToDisappear() {
    await this.playVideoModel.release();
    this.unregisterDescriptorChangesListener?.()
    this.cleanupCommandCallback?.()
  }

  registerCommandCallback() {
    if (this.ctx){
      this.cleanupCommandCallback = this.ctx.componentCommandReceiver.registerCommandCallback(
        this.tag,
        (command, args:(string|number)[]) => {
          if (command === 'seek') {
            //seek
            Logger.debug(`RNOH in RNCVideo: seek,  ${JSON.stringify(args)}`)
            Logger.debug(`RNOH in RNCVideo: seek, time: ${args[0]}`)
            Logger.debug(`RNOH in RNCVideo: seek, tolerance: ${args[1]}`)
            this.playVideoModel.setSeekTime(Number(args[0]))
          }
        });
    }
  }

  /* 更新属性变更  */
  updatePropFromDesc(){
    this.muted = this.descriptor.props.muted
    this.paused = this.descriptor.props.paused
    this.resizeMode = this.descriptor.props.resizeMode
    this.repeat = this.descriptor.props.repeat
    this.volume = this.descriptor.props.volume
    this.srcParam = this.descriptor.props.src.uri
    this.disableFocus = this.descriptor.props.disableFocus
    this.preventsDisplaySleepDuringVideoPlayback = this.descriptor.props.preventsDisplaySleepDuringVideoPlayback
    this.viewWidth = this.descriptor.layoutMetrics.frame.size.width
    this.viewHeight = this.descriptor.layoutMetrics.frame.size.height
    this.changedViewWidth = this.viewWidth
    this.changedviewHeight = this.viewHeight
    if(this.resizeMode === 'cover')
    {
      this.videoHeight = this.viewHeight
    }
  }

  /**
  *@brief onVideoLoad callback
  *@param startSecond 开始播放时间
  *@param length 视频长度
  *@param widthIn 视频width
  *@param heightIn 视频height
  *@param orientationIn 视频方向 对标安卓，通过视频宽高比对判断。
  *@return void
  */
  onVideoLoad(startSecond:number,length:number,widthIn:number,heightIn:number,orientationIn:string) {
    if (this.ctx){
      this.ctx.rnInstance.emitComponentEvent(this.descriptor.tag, RNC_VIDEO_TYPE,{
        type : "onVideoLoad",
        currentPosition : startSecond,
        duration:length,
        naturalSize:{
          width:widthIn,
          height:heightIn,
          orientation:orientationIn
        },
        audioTracks:this.playVideoModel.audioTracksBeanArr,
        videoTracks:this.playVideoModel.videoTracksBeanArr,

      })
    }
  }

  //
  onVideoEnd() {
    if (this.ctx){
      this.ctx.rnInstance.emitComponentEvent(this.descriptor.tag, RNC_VIDEO_TYPE,{
        type : "onVideoEnd",
      })
    }
  }
/**
 * 
 * @author hukang
 * @date 2023/10/18 11:49
 * @param cUri 当前视频URL
 * @return null
 */
  onVideoLoadStart(cUri: string) {
    if (this.ctx){
      this.ctx.rnInstance.emitComponentEvent(this.descriptor.tag, RNC_VIDEO_TYPE, {
        type: "onVideoLoadStart",
        isNetwork: this.descriptor.props.src.isNetwork,
        videoType: this.descriptor.props.src.type,
        uri: cUri
      })
    }
  }

  onReadyForDisplay() {
    if (this.ctx){
      this.ctx.rnInstance.emitComponentEvent(this.descriptor.tag, RNC_VIDEO_TYPE, {
        type: "onReadyForDisplay",
      })
    }
  }

  onVideoError(err:string) {
    if (this.ctx){
      this.ctx.rnInstance.emitComponentEvent(this.descriptor.tag, RNC_VIDEO_TYPE,{
        type : "onVideoError",
        error : err
      })
    }
  }

  onVideoProgress(time:number,_playableDuration:number = 0, _seekableDuration:number = 0) {
    if (this.ctx){
      this.ctx.rnInstance.emitComponentEvent(this.descriptor.tag, RNC_VIDEO_TYPE,{
        type : "onVideoProgress",
        currentTime : time,
        playableDuration : _playableDuration,
        seekableDuration : _seekableDuration
      })
    }
  }
  onVideoBuffer(isBufferingIn: boolean) {
    if (this.ctx){
      this.ctx.rnInstance.emitComponentEvent(this.descriptor.tag, RNC_VIDEO_TYPE,{
        type : "onVideoBuffer",
        isBuffering : isBufferingIn
      })
    }
  }

  onVideoPlaybackStalled() {
    if (this.ctx){
      this.ctx.rnInstance.emitComponentEvent(this.descriptor.tag, RNC_VIDEO_TYPE,{
        type : "onPlaybackStalled"
      })
    }
  }

  onVideoPlaybackResume() {
    if (this.ctx) {
      this.ctx.rnInstance.emitComponentEvent(this.descriptor.tag, RNC_VIDEO_TYPE,{
        type : "onPlaybackResume"
      })
    }
  }

  async getFd(){
    Logger.debug(`RNOH in RNCVideo getFd, ${(this.src)}`);
  }

  async preparePlayer() {
    Logger.debug(`RNOH in RNCVideo,preparePlayer src= ${(this.srcParam)}`);
    if (this.srcParam.startsWith('http')) {
      this.type = CommonConstants.TYPE_INTERNET
      this.src = this.srcParam
      Logger.debug(`RNOH in RNCVideo startsWith, finalsrc: ${(this.src)}`);
    } else {
      Logger.debug(`RNOH in RNCVideo local, finalsrc: ${(this.src)}`);
    }
  }

  onPageHide() {
    Logger.debug(`RNOH in RNCVideo onPageHide.`);
    this.playVideoModel.pause();
    this.isResume = true;
  }

  build() {
    RNViewBase({ ctx: this.ctx, tag: this.tag }) {
      PlayPlayer({ playVideoModel: this.playVideoModel, viewWidth: this.viewWidth, viewHeight: this.viewHeight })
        .align(Alignment.Center)
        .height(this.viewHeight)
        .width(this.viewWidth)
        .onDisAppear(async () => {
          await this.playVideoModel.release();
          this.unregisterDescriptorChangesListener?.()
          this.cleanupCommandCallback?.()
        })
    }
  }
}