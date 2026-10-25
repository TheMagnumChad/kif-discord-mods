# Hoenn's menu is a small command window, not another dialogue prompt.
# Hoenn's compact trainer commands, with controller input fully consumed.
module HoennEssentialsTrainerMenu
  def self.release_cancel
    # The map also listens for B. Never give it the same keypress.
    3.times do
      Graphics.update
      Input.update
    end
    frames = 0
    while Input.press?(Input::BACK) && frames < 120
      Graphics.update
      Input.update
      frames += 1
    end
    Graphics.update
    Input.update
  end

  def self.choose(options)
    cancel = options.index(_INTL('Cancel')) || options.length - 1
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 99999
    sprite = Sprite.new(viewport)
    line_h = 32
    width = [[options.map { |o| o.to_s.length }.max.to_i * 12 + 62, 176].max, Graphics.width - 16].min
    height = options.length * line_h + 20
    sprite.bitmap = Bitmap.new(width, height)
    pbSetSystemFont(sprite.bitmap)
    sprite.x = 8
    sprite.y = 8
    sprite.z = 99999
    selected = 0
    result = cancel
    redraw = proc do
      bmp = sprite.bitmap
      bmp.clear
      # Hoenn's compact charcoal menu with a thick, squared border.
      bmp.fill_rect(0, 0, width, height, Color.new(18, 22, 21))
      bmp.fill_rect(4, 4, width - 8, height - 8, Color.new(62, 67, 61))
      bmp.fill_rect(8, 8, width - 16, height - 16, Color.new(25, 36, 29))
      labels = []
      options.each_with_index do |option, i|
        y = 10 + i * line_h
        labels << [i == selected ? '▶' : ' ', 12, y, 0,
                   Color.new(248, 248, 248), Color.new(40, 40, 40)]
        labels << [option.to_s, 38, y, 0,
                   Color.new(248, 248, 248), Color.new(40, 40, 40)]
      end
      pbDrawTextPositions(bmp, labels)
    end
    redraw.call
    loop do
      Graphics.update
      Input.update
      if Input.repeat?(Input::DOWN)
        selected = (selected + 1) % options.length
        pbPlayCursorSE
        redraw.call
      elsif Input.repeat?(Input::UP)
        selected = (selected - 1) % options.length
        pbPlayCursorSE
        redraw.call
      elsif Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        result = cancel
        break
      elsif Input.trigger?(Input::USE)
        pbPlayDecisionSE
        result = selected
        break
      end
    end
    result
  ensure
    sprite.bitmap.dispose if sprite && sprite.bitmap && !sprite.bitmap.disposed?
    sprite.dispose if sprite && !sprite.disposed?
    viewport.dispose if viewport && !viewport.disposed?
    release_cancel if defined?(result) && result == cancel
  end
end

# Saved with the PokéNav itself, not temporary quiz scene state.
class Pokenav
  attr_accessor :hoenn_quiz_high_score
  attr_accessor :hoenn_quiz_total_points
  attr_accessor :hoenn_quiz_games_played
end

module HoennEssentialsQuizSave
  def quiz_nav
    return nil unless $Trainer
    $Trainer.pokenav = Pokenav.new unless $Trainer.pokenav
    $Trainer.pokenav
  end

  def quiz_stats
    nav = quiz_nav
    return [0, 0, 0] unless nav
    if nav.hoenn_quiz_high_score.nil?
      nav.hoenn_quiz_high_score = defined?(VAR_STAT_FUSION_QUIZ_HIGHEST_SCORE) ? pbGet(VAR_STAT_FUSION_QUIZ_HIGHEST_SCORE).to_i : 0
      nav.hoenn_quiz_total_points = defined?(VAR_STAT_FUSION_QUIZ_TOTAL_PTS) ? pbGet(VAR_STAT_FUSION_QUIZ_TOTAL_PTS).to_i : 0
      nav.hoenn_quiz_games_played = defined?(VAR_STAT_FUSION_QUIZ_NB_TIMES) ? pbGet(VAR_STAT_FUSION_QUIZ_NB_TIMES).to_i : 0
    end
    [nav.hoenn_quiz_high_score.to_i, nav.hoenn_quiz_total_points.to_i, nav.hoenn_quiz_games_played.to_i]
  end

  def launch_quiz
    difficulty = prompt_difficulty
    return unless difficulty
    rounds = prompt_nb_rounds(difficulty)
    return unless rounds && rounds > 0
    @scene.difficulty = difficulty
    @scene.playing = true
    @scene.updateBackground
    quiz = FusionQuiz.new(difficulty)
    quiz.silhouette_color = Color.new(0, 0, 0, 200)
    quiz.windowed = false
    quiz.picture_offset_x = difficulty == :ADVANCED ? -30 : -40
    quiz.picture_offset_y = 32
    quiz.start_quiz(rounds)
    return if quiz.player_abandonned
    score = quiz.get_score.to_i
    previous, total, played = quiz_stats
    nav = quiz_nav
    nav.hoenn_quiz_high_score = [previous, score].max
    nav.hoenn_quiz_total_points = total + score
    nav.hoenn_quiz_games_played = played + 1
    if score > previous
      pbMEPlay('Level Up')
      pbMessage(_INTL('You beat your previous high score!'))
    end
    unlock_new_modes(score)
  end

  def show_high_score
    high, total, played = quiz_stats
    pbMessage(_INTL('High Score: {1} pts', high))
    pbMessage(_INTL('Total Points: {1}\nGames Played: {2}', total, played))
  end
end

FusionQuizAppScreen.prepend(HoennEssentialsQuizSave) if defined?(FusionQuizAppScreen) && !FusionQuizAppScreen.ancestors.include?(HoennEssentialsQuizSave)
